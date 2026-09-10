import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/connection_model.dart';
import '../utils/asset_extractor.dart';
import 'database_service.dart';
import 'keychain_service.dart';

/// Manages the rclone process and RPC communication
class RcloneService {
  static Process? _process;
  static const int rpcPort = 5572;
  static const String rpcBase = 'http://127.0.0.1:$rpcPort';

  static String? _rcloneBinaryPath;

  // ─── Lifecycle ───────────────────────────────────────────────────────────

  static Future<void> start() async {
    if (_process != null) return;

    final binaryPath = await _resolveBinaryPath();
    _rcloneBinaryPath = binaryPath;
    final configPath = await _resolveConfigPath();

    final settings = await DatabaseService.getAllSettings();
    final proxyEnabled = settings['proxy_enabled'] == 'true';
    final proxyHost = settings['proxy_host'] ?? '';
    final proxyPort = settings['proxy_port'] ?? '8080';
    
    final upLimit = settings['upload_limit_mbps'] ?? '0';
    final downLimit = settings['download_limit_mbps'] ?? '0';
    final bwlimitArgs = <String>[];
    if (upLimit != '0' || downLimit != '0') {
      final up = upLimit == '0' ? 'off' : '${upLimit}M';
      final down = downLimit == '0' ? 'off' : '${downLimit}M';
      bwlimitArgs.add('--bwlimit=$up:$down');
    }

    final env = <String, String>{};
    if (proxyEnabled && proxyHost.isNotEmpty) {
      env['HTTP_PROXY'] = 'http://$proxyHost:$proxyPort';
      env['HTTPS_PROXY'] = 'http://$proxyHost:$proxyPort';
    }

    if (Platform.isWindows) {
      try {
        await Process.run('taskkill', ['/F', '/IM', 'rclone.exe']);
      } catch (_) {}
    }

    _process = await Process.start(binaryPath, [
      'rcd',
      '--rc-no-auth',
      '--rc-addr=127.0.0.1:$rpcPort',
      '--config=$configPath',
      '--log-level=INFO',
      ...bwlimitArgs,
    ], environment: env);

    _process!.stderr.transform(utf8.decoder).listen((data) {
      debugPrint('[rclone stderr] $data');
    });
    _process!.stdout.transform(utf8.decoder).listen((data) {});

    // Wait for RPC to be ready
    await _waitForReady();
  }

  static Future<void> stop() async {
    if (_process == null) return;
    try {
      await _rpc('/core/quit', {});
    } catch (_) {}
    // Kill the process and wait for it to exit
    _process?.kill();
    try {
      await _process?.exitCode;
    } catch (_) {}
    _process = null;
  }

  static Future<bool> healthCheck() async {
    try {
      await _rpc('/rc/noop', {}, skipReadyCheck: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> restart() async {
    await stop();
    await start();
  }

  // ─── Remote Configuration ─────────────────────────────────────────────

  static Future<void> configureRemote(
      String remoteName, ConnectionModel conn, String? credsJson) async {
    Map<String, dynamic> creds;
    if (credsJson != null) {
      try {
        creds = jsonDecode(credsJson) as Map<String, dynamic>;
      } catch (e) {
        throw Exception('Invalid credentials JSON: $e');
      }
    } else {
      creds = <String, dynamic>{};
    }

    final params = _buildRcloneParams(conn, creds);
    params.remove('type'); // Passed at top-level

    // Disable interactive setup for OAuth remotes (they already have tokens)
    if (conn.type.isOAuth) {
      params['config_is_local'] = 'false';
    }

    await _rpc('/config/create', {
      'name': remoteName,
      'type': conn.type.rcloneType,
      'parameters': params,
    });

    // If encrypted, create a crypt remote on top
    if (conn.isEncrypted) {
      final cryptPass = await KeychainService.getCryptPassword(conn.id);
      if (cryptPass != null) {
        await _rpc('/config/create', {
          'name': '${remoteName}_crypt',
          'type': 'crypt',
          'parameters': {
            'remote': '$remoteName:',
            'password': cryptPass,
          },
        });
      } else {
        throw Exception('Encryption password not found in keychain');
      }
    }
  }

  static Future<void> deleteRemote(String remoteName) async {
    try {
      await _rpc('/config/delete', {'name': remoteName});
      await _rpc('/config/delete', {'name': '${remoteName}_crypt'});
    } catch (_) {
      // Ignore errors if remote doesn't exist
    }
  }

  // ─── Mount / Unmount ──────────────────────────────────────────────────

  static Future<void> mountRemote(String remoteName, String mountPoint, ConnectionModel conn,
      {bool isEncrypted = false}) async {
    final fs = isEncrypted ? '${remoteName}_crypt:' : '$remoteName:';
    
    debugPrint('[RcloneService] Mounting $fs at $mountPoint');
    debugPrint('[RcloneService] Setting Volume Label: ${conn.name}');
    
    // Windows mount options for labeling and networking
    final mountOptions = <String, dynamic>{
      'AllowOther': false,
    };

    if (Platform.isWindows) {
      // These keys correspond to rclone's internal Mount names (CamelCase)
      // used in the mountOpt object for the RPC API.
      mountOptions['VolumeName'] = conn.name;
    }

    // VFS performance and reliability tweaks.
    final vfsOptions = <String, dynamic>{
      'CacheMode': 3,          // 3 = full
      'DirCacheTime': '5m',
      'AttrTimeout': '1m',
      'ReadChunkSize': '128M',
      // Disable VFS directory polling for OneDrive to prevent the infinite
      // "Failed to query root for drive" / "ObjectHandle is Invalid" loop.
      if (conn.type == ConnectionType.onedrive) 'PollInterval': '0',
    };

    // Filter out OneDrive's protected Personal Vault folder and system files.
    final Map<String, dynamic> filterOpt = conn.type == ConnectionType.onedrive
        ? {'Exclude': ['/Personal Vault/**', 'Thumbs.db', 'desktop.ini']}
        : {};

    await _rpc('/mount/mount', {
      'fs': fs,
      'mountPoint': mountPoint,
      'mountOpt': mountOptions,
      'vfsOpt': vfsOptions,
      if (filterOpt.isNotEmpty) '_filter': filterOpt,
      '_async': true,
    });
  }

  static Future<List<Map<String, dynamic>>> getActiveMounts() async {
    try {
      final result = await _rpc('/mount/listmounts', {});
      final mounts = result['mountPoints'] as List<dynamic>? ?? [];
      return mounts.map((m) => Map<String, dynamic>.from(m)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<String>> listMounts() async {
    final mounts = await getActiveMounts();
    return mounts.map((m) => m['MountPoint'].toString()).toList();
  }


  static Future<void> unmountRemote(String mountPoint) async {
    await _rpc('/mount/unmount', {'mountPoint': mountPoint});
  }

  static Future<void> unmountAll() async {
    try {
      await _rpc('/mount/unmountall', {});
    } catch (_) {}
  }

  // ─── Stats ────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getStats() async {
    try {
      final result = await _rpc('/core/stats', {});
      return result;
    } catch (_) {
      return {};
    }
  }

  static Future<Map<String, dynamic>> getAboutSize(String remoteName,
      {bool isEncrypted = false}) async {
    final fs = isEncrypted ? '${remoteName}_crypt:' : '$remoteName:';
    try {
      return await _rpc('/operations/size', {'fs': fs});
    } catch (e) {
      debugPrint('Error getting remote size: $e');
      return {};
    }
  }

  static Future<Map<String, dynamic>> getAboutDf(String remoteName,
      {bool isEncrypted = false}) async {
    final fs = isEncrypted ? '${remoteName}_crypt:' : '$remoteName:';
    try {
      return await _rpc('/operations/about', {'fs': fs});
    } catch (e) {
      debugPrint('Error getting remote df: $e');
      return {};
    }
  }

  static Future<void> setBandwidthLimit(int uploadMbps, int downloadMbps) async {
    final rate = uploadMbps > 0 || downloadMbps > 0
        ? '${uploadMbps > 0 ? "${uploadMbps}M" : "off"}:${downloadMbps > 0 ? "${downloadMbps}M" : "off"}'
        : 'off';
    await _rpc('/core/bwlimit', {'rate': rate});
  }

  // ─── OAuth ────────────────────────────────────────────────────────────

  static Future<String?> startOAuthConfig(
      String remoteName, ConnectionType type, Map<String, dynamic> params) async {
    debugPrint('[RcloneService] Starting clean OAuth flow for $type...');
    final binary = _rcloneBinaryPath ?? await _resolveBinaryPath();
    final configPath = await _resolveConfigPath();

    // STEP 1: Get the OAuth token using 'rclone authorize'
    // This opens the browser and waits for the user to authorize.
    final authArgs = [
      'authorize', type.rcloneType,
      '--config=$configPath',
    ];
    
    final process = await Process.start(binary, authArgs);
    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();

    final completer = Completer<String>();

    process.stdout.transform(utf8.decoder).listen((data) {
      stdoutBuffer.write(data);
      // Try to extract token dynamically
      final matches = RegExp(r'(\{.*?\})', dotAll: true).allMatches(stdoutBuffer.toString());
      if (matches.isNotEmpty) {
        try {
          final tokenStr = matches.last.group(1)!;
          // Validate it's actually JSON
          jsonDecode(tokenStr);
          if (!completer.isCompleted) {
            completer.complete(tokenStr);
          }
        } catch (_) {
          // Not valid JSON yet, keep buffering
        }
      }
    });

    process.stderr.transform(utf8.decoder).listen((data) {
      stderrBuffer.write(data);
    });

    try {
      final tokenJson = await completer.future.timeout(const Duration(minutes: 5));
      process.kill();
      
      // Step 3: Create the config non-interactively using the token
      // For OneDrive, we also pre-set stable defaults to avoid any further prompts.
      final createArgs = [
        'config', 'create', remoteName, type.rcloneType,
        '--config=$configPath',
        '--non-interactive',
        'token=$tokenJson',
        if (type == ConnectionType.onedrive) ...[
          'drive_type=${params['drive_type'] ?? 'personal'}',
          'no_versions=true',
          'chunk_size=10M',
        ],
        ...params.entries.where((e) => e.key != 'drive_type').map((e) => '${e.key}=${e.value}'),
      ];

      final createResult = await Process.run(binary, createArgs);
      if (createResult.exitCode != 0) {
        throw Exception('Failed to create config: ${createResult.stderr}');
      }

      String? discoveredDriveId;
      if (type == ConnectionType.onedrive) {
        final backendResult = await Process.run(binary, ['backend', 'drives', '$remoteName:', '--config=$configPath']);
        if (backendResult.exitCode == 0) {
          try {
            final drives = jsonDecode(backendResult.stdout) as List;
            if (drives.isNotEmpty) {
              discoveredDriveId = drives.first['id'];
            }
          } catch (_) {}
        }
      }

      final dumpResult = await Process.run(binary, ['config', 'dump', '--config=$configPath']);
      if (dumpResult.exitCode == 0) {
        try {
          final allConfigs = jsonDecode(dumpResult.stdout);
          final thisConfig = allConfigs[remoteName];
          if (thisConfig != null) {
            return jsonEncode({
              'token': thisConfig['token'] ?? tokenJson,
              'drive_id': discoveredDriveId ?? thisConfig['drive_id'],
              'drive_type': thisConfig['drive_type'],
            });
          }
        } catch (_) {}
      }

      return jsonEncode({'token': tokenJson});
    } catch (e) {
      process.kill();
      throw Exception('Authentication failed: $e\n${stderrBuffer.toString()}');
    }
  }

  // ─── List remote top-level folders ───────────────────────────────────

  static Future<List<String>> listRemoteFolders(String remoteName,
      {bool isEncrypted = false}) async {
    final fs = isEncrypted ? '${remoteName}_crypt:' : '$remoteName:';
    try {
      final result = await _rpc('/operations/list', {
        'fs': fs,
        'remote': '',
        'opt': {'recurse': false, 'dirsOnly': true},
      });
      final items = result['list'] as List<dynamic>? ?? [];
      return items.map((e) {
        if (e is Map) {
          final name = e['Name'];
          if (name is String) return name;
        }
        return null;
      }).whereType<String>().toList();
    } catch (_) {
      return [];
    }
  }

  // ─── Private helpers ──────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _rpc(
      String endpoint, Map<String, dynamic> body, {bool skipReadyCheck = false}) async {
    if (!skipReadyCheck) {
      await _waitForReady();
    }
    final client = HttpClient();
    try {
      final request = await client
          .postUrl(Uri.parse('$rpcBase$endpoint'))
          .timeout(const Duration(seconds: 15));
      request.headers.set('Content-Type', 'application/json');
      final payload = utf8.encode(jsonEncode(body));
      request.headers.contentLength = payload.length;
      request.add(payload);
      final response = await request.close().timeout(const Duration(seconds: 15));
      final responseBody = await response.transform(utf8.decoder).join().timeout(const Duration(seconds: 15));
      // Check content type before JSON decode
      Map<String, dynamic> data;
      try {
        data = jsonDecode(responseBody) as Map<String, dynamic>;
      } catch (e) {
        throw Exception('Invalid JSON response from rclone: $responseBody');
      }
      if (response.statusCode != 200 || data.containsKey('error')) {
        throw Exception(data['error'] ?? 'RPC Error: ${response.statusCode}');
      }
      return data;
    } finally {
      client.close();
    }
  }

  static Future<void> _waitForReady({int maxRetries = 30}) async {
    for (int i = 0; i < maxRetries; i++) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (await healthCheck()) return;
    }
    throw Exception('rclone RCD failed to start');
  }

  static Future<String> _resolveBinaryPath() async {
    return await AssetExtractor.ensureRcloneBinary();
  }

  static Future<String> _resolveConfigPath() async {
    final appDir = await getApplicationSupportDirectory();
    return p.join(appDir.path, 'rclone.conf');
  }

  static String? _validatePort(dynamic port) {
    if (port == null) return null;
    final s = port.toString().trim();
    if (s.isEmpty) return null;
    final n = int.tryParse(s);
    if (n == null || n <= 0 || n > 65535) return null;
    return s;
  }

  static Map<String, dynamic> _buildRcloneParams(
      ConnectionModel conn, Map<String, dynamic> creds) {
    final base = <String, dynamic>{'type': conn.type.rcloneType};
    switch (conn.type) {
      case ConnectionType.gdrive:
        return {
          ...base,
          'token': creds['token'] ?? '',
          'scope': 'drive',
        };
      case ConnectionType.dropbox:
        return {
          ...base,
          'token': creds['token'] ?? '',
        };
      case ConnectionType.onedrive:
        return {
          ...base,
          'token': creds['token'] ?? '',
          'drive_type': conn.config['drive_type'] ?? 'personal',
          'drive_id': conn.config['drive_id'] ?? '',
          'no_versions': 'true',
          'chunk_size': '10M',
        };
      case ConnectionType.mega:
        return {
          ...base,
          'user': conn.config['username'] ?? '',
          'pass': creds['password'] ?? '',
        };

    }
  }
}
