import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/connection_model.dart';
import '../models/activity_log_model.dart';
import 'database_service.dart';
import 'keychain_service.dart';
import 'rclone_service.dart';

class ConnectionService {
  static const _uuid = Uuid();

  // ─── CRUD ──────────────────────────────────────────────────────────────

  static Future<List<ConnectionModel>> listConnections() async {
    final db = await DatabaseService.db;
    final rows = await db.query('connections', orderBy: 'created_at DESC');
    final connections = rows.map(ConnectionModel.fromMap).toList();

    try {
      final activeMounts = await RcloneService.getActiveMounts();
      return connections.map((c) {
        final remoteName = _remoteName(c);
        final rcloneFs = '${remoteName}:';
        
        // Find if any active mount matches this connection's remote FS
        final matchingMount = activeMounts.firstWhere(
          (m) => m['Fs'] == rcloneFs || m['Fs'] == '${remoteName}_crypt:',
          orElse: () => {},
        );

        final isActuallyMounted = matchingMount.isNotEmpty;
        final actualMountPoint = matchingMount['MountPoint']?.toString();

        return c.copyWith(
          isMounted: isActuallyMounted,
          mountPoint: isActuallyMounted ? actualMountPoint : c.mountPoint,
        );
      }).toList();
    } catch (_) {
      return connections;
    }
  }

  static Future<ConnectionModel?> getConnection(String id) async {
    final db = await DatabaseService.db;
    final rows =
        await db.query('connections', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return ConnectionModel.fromMap(rows.first);
  }

  static Future<ConnectionModel> addConnection({
    required String name,
    required ConnectionType type,
    required Map<String, dynamic> config,
    required Map<String, dynamic> credentials,
    bool autoMount = false,
    bool isEncrypted = false,
    String? encryptionPassword,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    final model = ConnectionModel(
      id: id,
      name: name,
      type: type,
      config: config,
      autoMount: autoMount,
      isEncrypted: isEncrypted,
      createdAt: now,
    );

    final db = await DatabaseService.db;
    debugPrint('[ConnectionService] Saving connection: name="$name", id=$id');
    await db.insert('connections', model.toMap());
    
    // Verification log
    final saved = await db.query('connections', where: 'id = ?', whereArgs: [id]);
    if (saved.isNotEmpty) {
      debugPrint('[ConnectionService] DB VERIFY: name in DB is "${saved.first['name']}"');
    }

    // Store credentials in keychain
    if (credentials.isNotEmpty) {
      debugPrint('[ConnectionService] Storing credentials for $id');
      await KeychainService.storeCredentials(id, _jsonEncode(credentials));
    }

    // Store encryption password
    if (isEncrypted && encryptionPassword != null) {
      await KeychainService.storeCryptPassword(id, encryptionPassword);
    }

    await _logEvent(id, name, LogEventType.info, 'Connection "$name" created');
    return model;
  }

  static Future<void> updateConnection(
    String id, {
    String? name,
    Map<String, dynamic>? config,
    Map<String, dynamic>? credentials,
    bool? autoMount,
    bool? isEncrypted,
  }) async {
    final existing = await getConnection(id);
    if (existing == null) return;

    final updated = existing.copyWith(
      name: name,
      config: config,
      autoMount: autoMount,
      isEncrypted: isEncrypted,
    );

    final db = await DatabaseService.db;
    await db.update(
      'connections',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );

    if (credentials != null && credentials.isNotEmpty) {
      await KeychainService.storeCredentials(id, _jsonEncode(credentials));
    }
  }

  static Future<void> deleteConnection(String id) async {
    final conn = await getConnection(id);
    if (conn == null) return;

    // Unmount if mounted
    if (conn.isMounted && conn.mountPoint != null) {
      await _unmountSafe(conn.mountPoint!);
    }

    await KeychainService.deleteAll(id);
    await RcloneService.deleteRemote(_remoteName(conn));

    final db = await DatabaseService.db;
    await db.delete('connections', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Mount / Unmount ──────────────────────────────────────────────────

  static Future<String> mount(ConnectionModel conn) async {
    debugPrint('[ConnectionService] Starting mount for "${conn.name}" (id: ${conn.id})');
    final credsJson = await KeychainService.getCredentials(conn.id);
    final remoteName = _remoteName(conn);

    // (Re)write rclone remote config
    debugPrint('[ConnectionService] Configuring rclone remote: $remoteName');
    await RcloneService.configureRemote(remoteName, conn, credsJson);

    // Determine mount point (refining selection)
    String mountPoint = conn.mountPoint ?? await _nextMountPoint(conn.name);
    
    // Normalize Windows drive letter: Rclone prefers "G:" over "G:\"
    if (Platform.isWindows && mountPoint.endsWith('\\')) {
      mountPoint = mountPoint.substring(0, mountPoint.length - 1);
    }
    debugPrint('[ConnectionService] Assigned Mount Point: $mountPoint');

    // Proactively check if this connection is ALREADY mounted somewhere
    final allMounts = await RcloneService.getActiveMounts();
    final rcloneFs = '${remoteName}:';
    final existingMount = allMounts.firstWhere(
      (m) => m['Fs'] == rcloneFs || m['Fs'] == '${remoteName}_crypt:',
      orElse: () => {},
    );

    if (existingMount.isNotEmpty) {
      final existingPoint = existingMount['MountPoint'].toString();
      debugPrint('[ConnectionService] Connection already mounted at $existingPoint. Skipping new mount.');
      return existingPoint;
    }

    // Proactively unmount any stale mount at the target letter
    if (allMounts.any((m) => m['MountPoint'] == mountPoint)) {
      debugPrint('[ConnectionService] Target $mountPoint is busy in rclone, unmounting first');
      await _unmountSafe(mountPoint);
    } else if (Platform.isWindows) {
      // Even if not in rclone, try a safe unmount to clear Windows Mount Manager cache
      await _unmountSafe(mountPoint);
    }


    // Ensure mount directory exists (Linux/macOS)
    if (!Platform.isWindows) {
      await Directory(mountPoint).create(recursive: true);
    }

    debugPrint('[ConnectionService] Calling RcloneService.mountRemote');
    await RcloneService.mountRemote(
      remoteName,
      mountPoint,
      conn,
      isEncrypted: conn.isEncrypted,
    );

    // Wait for the mount to become available (poll for up to 30 seconds)
    bool mounted = false;
    const maxAttempts = 60; // 30 seconds with 500ms intervals
    for (int i = 0; i < maxAttempts; i++) {
      try {
        // 1. Check if rclone reports it as mounted
        final active = await RcloneService.listMounts();
        if (active.contains(mountPoint)) {
          // 2. Check if the OS sees the mount point
          final dir = Directory(Platform.isWindows ? '$mountPoint\\' : mountPoint);
          if (await dir.exists()) {
            // 3. Verify accessibility: try to list contents
            try {
              await dir.list().isEmpty.timeout(const Duration(milliseconds: 800));
              mounted = true;
              debugPrint('[ConnectionService] Mount verification successful for $mountPoint');
              break;
            } catch (e) {
              // Accessible check failed — wait for FUSE/WinFsp to fully initialize
              debugPrint('[ConnectionService] Directory exists but not yet accessible: $e');
            }
          }
        }
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 500));
    }


    if (!mounted) {
      throw Exception(
          'Mount failed after 30 seconds. Ensure WinFsp is installed on Windows, or FUSE on macOS/Linux.');
    }

    // Persist mount state
    final db = await DatabaseService.db;
    await db.update(
      'connections',
      {
        'mount_point': mountPoint,
        'last_mounted': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [conn.id],
    );

    await _logEvent(
        conn.id, conn.name, LogEventType.mount, 'Mounted at $mountPoint');
    return mountPoint;
  }

  static Future<void> unmount(ConnectionModel conn) async {
    final remoteName = _remoteName(conn);
    final rcloneFs = '${remoteName}:';
    final rcloneFsCrypt = '${remoteName}_crypt:';

    // Get all active mounts from rclone
    final allMounts = await RcloneService.getActiveMounts();
    
    // Find all mount points matching this connection
    final pointsToUnmount = allMounts
        .where((m) => m['Fs'] == rcloneFs || m['Fs'] == rcloneFsCrypt)
        .map((m) => m['MountPoint'].toString())
        .toList();

    // If we have any active mounts in rclone, unmount them all
    if (pointsToUnmount.isNotEmpty) {
      for (final point in pointsToUnmount) {
        await _unmountSafe(point);
      }
    } else if (conn.mountPoint != null) {
      // Fallback: if rclone doesn't see it but DB has it, try unmounting the DB point anyway
      await _unmountSafe(conn.mountPoint!);
    }

    final db = await DatabaseService.db;
    await db.update(
      'connections',
      {'mount_point': null},
      where: 'id = ?',
      whereArgs: [conn.id],
    );

    await _logEvent(
        conn.id, conn.name, LogEventType.unmount, 'Unmounted all points');
  }

  static Future<void> unmountAll(List<ConnectionModel> connections) async {
    await RcloneService.unmountAll();
    final db = await DatabaseService.db;
    for (final conn in connections.where((c) => c.isMounted)) {
      await db.update(
        'connections',
        {'mount_point': null},
        where: 'id = ?',
        whereArgs: [conn.id],
      );
    }
  }

  // ─── Activity Log ─────────────────────────────────────────────────────

  static Future<List<ActivityLogEntry>> getActivityLog({
    String? connId,
    LogEventType? eventType,
    DateTime? from,
    DateTime? to,
    int limit = 200,
  }) async {
    final db = await DatabaseService.db;
    final where = <String>[];
    final args = <dynamic>[];

    if (connId != null) {
      where.add('conn_id = ?');
      args.add(connId);
    }
    if (eventType != null) {
      where.add('event_type = ?');
      args.add(eventType.name);
    }
    if (from != null) {
      where.add('timestamp >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.add('timestamp <= ?');
      args.add(to.toIso8601String());
    }

    final rows = await db.query(
      'activity_log',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return rows.map(ActivityLogEntry.fromMap).toList();
  }

  static Future<String> exportLogsCsv({
    String? connId,
    LogEventType? eventType,
  }) async {
    final entries = await getActivityLog(connId: connId, eventType: eventType, limit: 10000);
    final buffer = StringBuffer();
    buffer.writeln('Timestamp,Connection,Event,Message,Bytes,Speed (bps)');
    for (final e in entries) {
      buffer.writeln(
          '${e.timestamp.toIso8601String()},${_csvEscape(e.connName)},${e.eventType.name},${_csvEscape(e.message)},${e.bytes},${e.speedBps}');
    }

    final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'cloudmounter_log_${DateTime.now().millisecondsSinceEpoch}.csv'));
    try {
      await file.writeAsString(buffer.toString());
    } catch (e) {
      throw Exception('Failed to write CSV file: $e');
    }
    return file.path;
  }

  // ─── Private helpers ──────────────────────────────────────────────────

  static Future<void> _logEvent(
      String connId, String connName, LogEventType type, String message,
      {int bytes = 0, int speedBps = 0}) async {
    final db = await DatabaseService.db;
    await db.insert('activity_log', {
      'conn_id': connId,
      'conn_name': connName,
      'event_type': type.name,
      'message': message,
      'bytes': bytes,
      'speed_bps': speedBps,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> _unmountSafe(String mountPoint) async {
    try {
      await RcloneService.unmountRemote(mountPoint);
    } catch (e, _) {
      // Log but continue — unmount may fail if already unmounted
      debugPrint('Failed to unmount $mountPoint: $e');
    }
  }

  static String _remoteName(ConnectionModel conn) =>
      'cm_${conn.id.replaceAll('-', '_')}';

  static Future<String> _nextMountPoint(String name) async {
    final sanitized = name.replaceAll(' ', '_').replaceAll('/', '_').replaceAll('\\', '_');

    if (Platform.isWindows) {
      // Find next available drive letter E-Z
      for (final letter in 'EFGHIJKLMNOPQRSTUVWXYZ'.split('')) {
        final drive = '$letter:';
        try {
          // On Windows, checking if 'G:\' exists is the reliable way to see if a drive letter is taken
          if (!await Directory('$drive\\').exists()) {
            return drive;
          }
        } catch (_) {
          // If we can't access, it might be a broken mount or available
          return drive;
        }
      }
      return 'G:';
    } else if (Platform.isMacOS) {
      var basePath = '/Volumes/$sanitized';
      var counter = 1;
      while (await Directory(basePath).exists()) {
        basePath = '/Volumes/${sanitized}_$counter';
        counter++;
      }
      return basePath;
    } else {
      final home = Platform.environment['HOME'] ?? '/home/user';
      var basePath = '$home/CloudMounts/$sanitized';
      var counter = 1;
      while (await Directory(basePath).exists()) {
        basePath = '$home/CloudMounts/${sanitized}_$counter';
        counter++;
      }
      return basePath;
    }
  }

  static String _jsonEncode(Map<String, dynamic> map) {
    return jsonEncode(map);
  }

  static String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
