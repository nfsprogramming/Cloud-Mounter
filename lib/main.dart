import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';

import 'screens/home_screen.dart';
import 'screens/add_connection_screen.dart';
import 'screens/settings_screen.dart';
import 'services/connection_service.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'services/rclone_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init SQLite for desktop
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Init DB schema
  await DatabaseService.db;

  // Init window
  await windowManager.ensureInitialized();
  await windowManager.setMinimumSize(const Size(900, 600));
  await windowManager.setSize(const Size(1100, 700));
  await windowManager.setTitle('CloudMounter');
  if (Platform.isWindows) {
    await windowManager.setIcon('assets/icons/app_icon.ico');
  }
  await windowManager.center();
  await windowManager.setPreventClose(true);

  await NotificationService.init();

  // Start rclone RCD (non-blocking — UI loads first)
  _startRclone();

  runApp(const ProviderScope(child: CloudMounterApp()));
}

Future<void> _startRclone() async {
  try {
    await RcloneService.start();
  } catch (e) {
    debugPrint('Failed to start rclone: $e');
  }
}

class CloudMounterApp extends StatefulWidget {
  const CloudMounterApp({super.key});

  @override
  State<CloudMounterApp> createState() => _CloudMounterAppState();
}

class _CloudMounterAppState extends State<CloudMounterApp>
    with TrayListener, WindowListener {

  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    windowManager.addListener(this);
    _setupTray();
    _initAutoMount();
  }

  Future<void> _initAutoMount() async {
    await Future.delayed(const Duration(seconds: 2));
    final settings = await DatabaseService.getAllSettings();
    if (settings['auto_mount_on_launch'] == 'true') {
      final connections = await ConnectionService.listConnections();
      for (final conn in connections) {
        if (conn.autoMount) {
          try {
            await ConnectionService.mount(conn);
          } catch (e) {
            debugPrint('Failed to auto-mount ${conn.name}: $e');
          }
        }
      }
    }
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _setupTray() async {
    await trayManager.setIcon(
      Platform.isWindows ? 'assets/icons/tray_icon.ico' : 'assets/icons/tray_icon.png',
    );
    await trayManager.setToolTip('CloudMounter');
    await _updateTrayMenu();
  }

  Future<void> _updateTrayMenu() async {
    final menu = Menu(
      items: [
        MenuItem(key: 'show', label: 'Open CloudMounter'),
        MenuItem.separator(),
        MenuItem(key: 'exit', label: 'Exit'),
      ],
    );
    await trayManager.setContextMenu(menu);
  }

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show') windowManager.show();
    if (menuItem.key == 'exit') _quit();
  }

  @override
  Future<bool> onWindowClose() async {
    // Hide to tray instead of quit
    await windowManager.hide();
    return false;
  }

  Future<void> _quit() async {
    await RcloneService.unmountAll();
    await RcloneService.stop();
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CloudMounter',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: '/',
      routes: {
        '/': (ctx) => const HomeScreen(),
        '/add-connection': (ctx) => const AddConnectionScreen(),
        '/settings': (ctx) => const SettingsScreen(),
      },
    );
  }
}
