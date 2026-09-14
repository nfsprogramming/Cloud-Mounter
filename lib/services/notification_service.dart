import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:local_notifier/local_notifier.dart';

import 'database_service.dart';

class NotificationService {
  static Future<void> init() async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;
    try {
      await localNotifier.setup(
        appName: 'CloudMounter',
        shortcutPolicy: ShortcutPolicy.requireCreate,
      );
    } catch (e) {
      debugPrint('Failed to init local_notifier: $e');
    }
  }

  static Future<void> showMountEvent(String title, String body, {bool isError = false}) async {
    final settings = await DatabaseService.getAllSettings();
    final notifyMount = settings['notify_mount'] == 'true';
    final notifyError = settings['notify_error'] == 'true';

    if (isError) {
      // If error, show regardless of notify_mount (errors only check)
      _show(title, body);
    } else if (notifyMount && !notifyError) {
      _show(title, body);
    }
  }

  static Future<void> showTransferEvent(String title, String body, {bool isError = false}) async {
    final settings = await DatabaseService.getAllSettings();
    final notifyTransfer = settings['notify_transfer'] == 'true';
    final notifyError = settings['notify_error'] == 'true';

    if (isError) {
      _show(title, body);
    } else if (notifyTransfer && !notifyError) {
      _show(title, body);
    }
  }
  
  static Future<void> showError(String title, String body) async {
    _show(title, body);
  }

  static void _show(String title, String body) {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;
    try {
      final notification = LocalNotification(
        title: title,
        body: body,
      );
      notification.show();
    } catch (e) {
      debugPrint('Failed to show notification: $e');
    }
  }
}
