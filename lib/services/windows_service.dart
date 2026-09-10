import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart' as p;

class WindowsService {
  static const String _registryKey = r'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run';
  static const String _appName = 'CloudMounter';

  static Future<void> setLaunchAtStartup(bool enabled) async {
    if (!Platform.isWindows) return;

    try {
      final executablePath = Platform.resolvedExecutable;
      
      if (enabled) {
        // Add to registry
        final command = 'Set-ItemProperty -Path "$_registryKey" -Name "$_appName" -Value "$executablePath"';
        await Process.run('powershell', ['-Command', command]);
        debugPrint('[WindowsService] Enabled launch at startup');
      } else {
        // Remove from registry
        final command = 'Remove-ItemProperty -Path "$_registryKey" -Name "$_appName" -ErrorAction SilentlyContinue';
        await Process.run('powershell', ['-Command', command]);
        debugPrint('[WindowsService] Disabled launch at startup');
      }
    } catch (e) {
      debugPrint('[WindowsService] Error setting startup: $e');
    }
  }

  static Future<bool> isLaunchAtStartupEnabled() async {
    if (!Platform.isWindows) return false;

    try {
      final command = 'Get-ItemProperty -Path "$_registryKey" -Name "$_appName" -ErrorAction SilentlyContinue';
      final result = await Process.run('powershell', ['-Command', command]);
      return result.stdout.toString().contains(_appName);
    } catch (_) {
      return false;
    }
  }

  static Future<void> createDesktopShortcut() async {
    if (!Platform.isWindows) return;

    try {
      final executablePath = Platform.resolvedExecutable;
      final desktopPath = p.join(Platform.environment['USERPROFILE']!, 'Desktop', 'CloudMounter.lnk');
      
      final command = '''
\$WshShell = New-Object -ComObject WScript.Shell
\$Shortcut = \$WshShell.CreateShortcut("$desktopPath")
\$Shortcut.TargetPath = "$executablePath"
\$Shortcut.WorkingDirectory = "${p.dirname(executablePath)}"
\$Shortcut.Save()
''';
      await Process.run('powershell', ['-Command', command]);
      debugPrint('[WindowsService] Desktop shortcut created');
    } catch (e) {
      debugPrint('[WindowsService] Error creating shortcut: $e');
    }
  }
}
