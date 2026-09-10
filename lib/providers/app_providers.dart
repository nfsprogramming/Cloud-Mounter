import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/connection_model.dart';
import '../models/activity_log_model.dart';
import '../services/connection_service.dart';
import '../services/rclone_service.dart';
import '../services/database_service.dart';
import '../services/windows_service.dart';

// ─── Connections Provider ────────────────────────────────────────────────────

class ConnectionsNotifier extends AsyncNotifier<List<ConnectionModel>> {
  @override
  Future<List<ConnectionModel>> build() async {
    return ConnectionService.listConnections();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(ConnectionService.listConnections);
  }

  Future<void> addConnection({
    required String name,
    required ConnectionType type,
    required Map<String, dynamic> config,
    required Map<String, dynamic> credentials,
    bool autoMount = false,
    bool isEncrypted = false,
    String? encryptionPassword,
  }) async {
    await ConnectionService.addConnection(
      name: name,
      type: type,
      config: config,
      credentials: credentials,
      autoMount: autoMount,
      isEncrypted: isEncrypted,
      encryptionPassword: encryptionPassword,
    );
    await refresh();
  }

  Future<void> deleteConnection(String id) async {
    await ConnectionService.deleteConnection(id);
    await refresh();
  }

  Future<void> mountConnection(String id) async {
    _updateMountState(id, isMounting: true, clearError: true);
    try {
      final conn = state.value?.firstWhere((c) => c.id == id);
      if (conn == null) return;
      final mountPoint = await ConnectionService.mount(conn);
      _updateMountState(id,
          isMounting: false, isMounted: true, mountPoint: mountPoint);
    } catch (e) {
      _updateMountState(id,
          isMounting: false, isMounted: false, error: e.toString());
    }
    await refresh();
  }

  Future<void> unmountConnection(String id) async {
    _updateMountState(id, isMounting: true, clearError: true);
    try {
      final conn = state.value?.firstWhere((c) => c.id == id);
      if (conn == null) return;
      await ConnectionService.unmount(conn);
      _updateMountState(id,
          isMounting: false, isMounted: false, clearMountPoint: true);
    } catch (e) {
      _updateMountState(id, isMounting: false, error: e.toString());
    }
    // Do not call refresh() here as it would overwrite UI-only flags
  }

  Future<void> unmountAll() async {
    final connections = state.value ?? [];
    await ConnectionService.unmountAll(connections);
    await refresh();
  }

  Future<void> mountAll() async {
    final connections = state.value ?? [];
    for (final c in connections) {
      if (!c.isMounted && c.mountError == null) {
        await mountConnection(c.id);
      }
    }
  }

  void _updateMountState(
    String id, {
    bool? isMounting,
    bool? isMounted,
    String? mountPoint,
    String? error,
    bool clearError = false,
    bool clearMountPoint = false,
  }) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.map((c) {
      if (c.id != id) return c;
      return c.copyWith(
        isMounting: isMounting,
        isMounted: isMounted,
        mountPoint: mountPoint,
        mountError: error,
        clearMountError: clearError,
        clearMountPoint: clearMountPoint,
      );
    }).toList());
  }
}

final connectionsProvider =
    AsyncNotifierProvider<ConnectionsNotifier, List<ConnectionModel>>(
        ConnectionsNotifier.new);

// ─── Selected Connection Provider ────────────────────────────────────────────

final selectedConnectionIdProvider = NotifierProvider<_SelectedIdNotifier, String?>(
    _SelectedIdNotifier.new);

class _SelectedIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? id) => state = id;
}

final selectedConnectionProvider = Provider<ConnectionModel?>((ref) {
  final id = ref.watch(selectedConnectionIdProvider);
  final connections = ref.watch(connectionsProvider).value ?? [];
  if (id == null) return null;
  try {
    return connections.firstWhere((c) => c.id == id);
  } catch (_) {
    return null;
  }
});

// ─── Activity Log Provider ───────────────────────────────────────────────────

class ActivityLogNotifier
    extends AsyncNotifier<List<ActivityLogEntry>> {
  String? _filterConnId;
  LogEventType? _filterType;

  @override
  Future<List<ActivityLogEntry>> build() async {
    return ConnectionService.getActivityLog();
  }

  Future<void> refresh({String? connId, LogEventType? type}) async {
    _filterConnId = connId;
    _filterType = type;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ConnectionService.getActivityLog(
          connId: _filterConnId, eventType: _filterType),
    );
  }
}

final activityLogProvider =
    AsyncNotifierProvider<ActivityLogNotifier, List<ActivityLogEntry>>(
        ActivityLogNotifier.new);

// ─── Stats Provider (rclone live stats) ──────────────────────────────────────

final rcloneStatsProvider =
    StreamProvider.autoDispose<Map<String, dynamic>>((ref) async* {
  while (true) {
    await Future.delayed(const Duration(seconds: 2));
    try {
      final stats = await RcloneService.getStats();
      yield stats;
    } catch (e, _) {
      // Yield empty map on error to keep stream alive
      yield <String, dynamic>{};
    }
  }
});

// ─── Storage Provider (remote size/usage) ───────────────────────────────────

final storageProvider = StreamProvider.autoDispose.family<Map<String, dynamic>, String>((ref, connId) async* {
  final connections = ref.watch(connectionsProvider).value ?? [];
  final conn = connections.firstWhere((c) => c.id == connId, orElse: () => throw Exception('Connection not found'));
  
  final remoteName = 'cm_${conn.id.replaceAll('-', '_')}';
  
  while (true) {
    try {
      // Get both size (count, total bytes) and about (usage/quota)
      final size = await RcloneService.getAboutSize(remoteName, isEncrypted: conn.isEncrypted);
      final df = await RcloneService.getAboutDf(remoteName, isEncrypted: conn.isEncrypted);
      
      yield {
        'count': size['count'] ?? 0,
        'bytes': size['bytes'] ?? 0,
        'total': df['total'] ?? 0,
        'used': df['used'] ?? 0,
        'free': df['free'] ?? 0,
      };
    } catch (e) {
      yield <String, dynamic>{};
    }
    
    // Poll every 30 seconds for storage updates
    await Future.delayed(const Duration(seconds: 30));
  }
});

// ─── Settings Provider ───────────────────────────────────────────────────────

class SettingsNotifier extends AsyncNotifier<Map<String, String>> {
  @override
  Future<Map<String, String>> build() async {
    return DatabaseService.getAllSettings();
  }

  Future<void> set(String key, String value) async {
    await DatabaseService.setSetting(key, value);
    
    if (key == 'launch_at_startup') {
      await WindowsService.setLaunchAtStartup(value == 'true');
    } else if (key == 'upload_limit_mbps' || key == 'download_limit_mbps') {
      final settings = await DatabaseService.getAllSettings();
      final up = int.tryParse(settings['upload_limit_mbps'] ?? '0') ?? 0;
      final down = int.tryParse(settings['download_limit_mbps'] ?? '0') ?? 0;
      await RcloneService.setBandwidthLimit(up, down);
    } else if (key == 'proxy_enabled' || key == 'proxy_host' || key == 'proxy_port') {
      await RcloneService.restart();
    }
    
    state = await AsyncValue.guard(DatabaseService.getAllSettings);
  }

  String get(String key, {String defaultValue = ''}) {
    return state.value?[key] ?? defaultValue;
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, Map<String, String>>(
        SettingsNotifier.new);

// ─── Rclone health check timer ───────────────────────────────────────────────

final rcloneHealthProvider = StreamProvider.autoDispose<bool>((ref) async* {
  while (true) {
    await Future.delayed(const Duration(seconds: 30));
    final healthy = await RcloneService.healthCheck();
    if (!healthy) {
      await RcloneService.restart();
    }
    yield healthy;
  }
});
