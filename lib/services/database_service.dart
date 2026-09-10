import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseService {
  static Database? _db;

  static Future<Database> get db async {
    _db ??= await _init();
    return _db!;
  }

  static Future<Database> _init() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final appDir = await getApplicationSupportDirectory();
    final dbPath = p.join(appDir.path, 'cloudmounter.db');

    return await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE connections (
        id            TEXT PRIMARY KEY,
        name          TEXT NOT NULL,
        conn_type     TEXT NOT NULL,
        config_json   TEXT NOT NULL DEFAULT '{}',
        keychain_key  TEXT,
        auto_mount    INTEGER DEFAULT 0,
        is_encrypted  INTEGER DEFAULT 0,
        mount_point   TEXT,
        created_at    TEXT NOT NULL,
        last_mounted  TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE activity_log (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        conn_id       TEXT NOT NULL,
        conn_name     TEXT NOT NULL DEFAULT '',
        event_type    TEXT NOT NULL,
        message       TEXT DEFAULT '',
        bytes         INTEGER DEFAULT 0,
        speed_bps     INTEGER DEFAULT 0,
        timestamp     TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Default settings
    final defaults = {
      'theme': 'dark',
      'auto_mount_on_launch': 'true',
      'launch_at_startup': 'false',
      'upload_limit_mbps': '0',
      'download_limit_mbps': '0',
      'notify_mount': 'true',
      'notify_transfer': 'true',
      'notify_error': 'true',
      'proxy_enabled': 'false',
      'proxy_host': '',
      'proxy_port': '8080',
    };

    for (final entry in defaults.entries) {
      await db.insert('settings', {'key': entry.key, 'value': entry.value});
    }
  }

  static Future<void> _onUpgrade(Database db, int oldV, int newV) async {}

  static Future<String?> getSetting(String key) async {
    final database = await db;
    final rows = await database.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  static Future<void> setSetting(String key, String value) async {
    final database = await db;
    await database.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<Map<String, String>> getAllSettings() async {
    final database = await db;
    final rows = await database.query('settings');
    return {for (final r in rows) r['key'] as String: r['value'] as String};
  }
}
