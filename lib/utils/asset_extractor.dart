import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AssetExtractor {
  static Future<String> ensureRcloneBinary() async {
    final appDir = await getApplicationSupportDirectory();
    final binDir = Directory(p.join(appDir.path, 'bin'));
    if (!await binDir.exists()) {
      await binDir.create(recursive: true);
    }

    final String binaryName;
    final String assetName;

    if (Platform.isWindows) {
      binaryName = 'rclone.exe';
      assetName = 'assets/binaries/rclone-windows-amd64.exe';
    } else if (Platform.isMacOS) {
      binaryName = 'rclone';
      assetName = 'assets/binaries/rclone-macos-arm64'; // adjust for Intel if needed
    } else {
      binaryName = 'rclone';
      assetName = 'assets/binaries/rclone-linux-amd64';
    }

    final destFile = File(p.join(binDir.path, binaryName));

    // If already exists and size > 0, assume it's good
    if (await destFile.exists() && await destFile.length() > 0) {
      return destFile.path;
    }

    // Otherwise, copy from assets or download
    try {
      final byteData = await rootBundle.load(assetName);
      final bytes = byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
      await destFile.writeAsBytes(bytes);
     } catch (e) {
       debugPrint('Asset not found, downloading rclone...: $e');
      // Download and extract
      final tempZip = File(p.join(binDir.path, 'rclone.zip'));
      HttpClient? client;
      try {
        client = HttpClient();
        final request = await client.getUrl(Uri.parse(_getDownloadUrl()));
        final response = await request.close();
        if (response.statusCode != 200) {
          throw Exception('Download failed: HTTP ${response.statusCode}');
        }
        await response.pipe(tempZip.openWrite());
      } finally {
        client?.close();
      }

      // Extract based on platform
      Directory? extractedDir;
      try {
        if (Platform.isWindows) {
          // Use PowerShell to extract
          final psResult = await Process.run('powershell', [
            '-Command',
            'Expand-Archive -Path "${tempZip.path}" -DestinationPath "${binDir.path}" -Force'
          ]);
          if (psResult.exitCode != 0) {
            throw Exception('PowerShell extraction failed: ${psResult.stderr}');
          }
          // The zip contains a top-level folder; find rclone.exe inside
          final expectedDir = Directory(p.join(binDir.path, 'rclone-v1.68.1-windows-amd64'));
          if (await expectedDir.exists()) {
            extractedDir = expectedDir;
          } else {
            // Search for any .exe inside extracted directories
            extractedDir = await _findExtractedDirWithExe(binDir);
          }
        } else {
          // Use unzip on Unix-like
          final unzipResult = await Process.run('unzip', ['-o', tempZip.path, '-d', binDir.path]);
          if (unzipResult.exitCode != 0) {
            throw Exception('unzip failed: ${unzipResult.stderr}');
          }
          // Determine expected folder name based on platform
          String expectedFolder;
          if (Platform.isMacOS) {
            expectedFolder = 'rclone-v1.68.1-osx-arm64';
          } else {
            expectedFolder = 'rclone-v1.68.1-linux-amd64';
          }
          extractedDir = Directory(p.join(binDir.path, expectedFolder));
          if (!await extractedDir.exists()) {
            extractedDir = await _findExtractedDirWithBinary(binDir, binaryName);
          }
        }

        if (extractedDir == null || !await extractedDir.exists()) {
          throw Exception('Extracted directory not found');
        }

        final extractedBinary = File(p.join(extractedDir.path, binaryName));
        if (!await extractedBinary.exists()) {
          throw Exception('Extracted binary not found at ${extractedBinary.path}');
        }

        // Copy to final destination
        await extractedBinary.copy(destFile.path);
      } finally {
        // Cleanup temp zip and extracted folder
        if (await tempZip.exists()) await tempZip.delete();
        if (extractedDir != null && await extractedDir.exists()) {
          await extractedDir.delete(recursive: true);
        }
      }
    }

    // Ensure executable permission on non-Windows
    if (!Platform.isWindows && await destFile.exists()) {
      await Process.run('chmod', ['+x', destFile.path]);
    }

    if (await destFile.exists()) {
      return destFile.path;
    }

    throw Exception('Failed to obtain rclone binary');
  }

  static String _getDownloadUrl() {
    final version = 'v1.68.1';
    if (Platform.isWindows) {
      return 'https://downloads.rclone.org/$version/rclone-$version-windows-amd64.zip';
    } else if (Platform.isMacOS) {
      return 'https://downloads.rclone.org/$version/rclone-$version-osx-arm64.zip';
    } else {
      return 'https://downloads.rclone.org/$version/rclone-$version-linux-amd64.zip';
    }
  }

  static Future<Directory?> _findExtractedDirWithExe(Directory binDir) async {
    try {
      await for (final entity in binDir.list(recursive: false)) {
        if (entity is Directory) {
          final exe = File(p.join(entity.path, 'rclone.exe'));
          if (await exe.exists()) return entity;
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<Directory?> _findExtractedDirWithBinary(Directory binDir, String binaryName) async {
    try {
      await for (final entity in binDir.list(recursive: false)) {
        if (entity is Directory) {
          final bin = File(p.join(entity.path, binaryName));
          if (await bin.exists()) return entity;
        }
      }
    } catch (_) {}
    return null;
  }
}
