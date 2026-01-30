import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../utils/logger.dart';

class UpdateInfo {
  final bool hasUpdate;
  final String latestVersion;
  final String downloadUrl;
  final String releaseNotes;

  UpdateInfo({
    required this.hasUpdate,
    required this.latestVersion,
    required this.downloadUrl,
    required this.releaseNotes,
  });
}

class UpdateService {
  static const String _githubApiUrl =
      'https://api.github.com/repos/shindozk/Luyumi-Launcher/releases/latest';

  Future<UpdateInfo> checkForUpdates() async {
    try {
      // 1. Get Current Version from settings.json (Asset)
      String currentVersion = '1.0.0'; // Fallback
      try {
        final settingsJson = await rootBundle.loadString('lib/config/settings.json');
        final settingsData = jsonDecode(settingsJson);
        currentVersion = settingsData['launcher_version'] ?? '1.0.0';
      } catch (e) {
        Logger.warning('Failed to load settings.json version, falling back to package_info: $e');
        final packageInfo = await PackageInfo.fromPlatform();
        currentVersion = packageInfo.version;
      }

      Logger.info('Current Version: $currentVersion');

      // 2. Fetch Latest Release from GitHub
      final response = await http.get(Uri.parse(_githubApiUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch updates: ${response.statusCode}');
      }

      final releaseData = jsonDecode(response.body);
      final String tagName = releaseData['tag_name']; // e.g., "v1.5.0"
      final String latestVersion = tagName.startsWith('v') 
          ? tagName.substring(1) 
          : tagName;

      Logger.info('Latest Version: $latestVersion');

      // 3. Compare Versions
      if (!_isNewerVersion(currentVersion, latestVersion)) {
        return UpdateInfo(
          hasUpdate: false,
          latestVersion: latestVersion,
          downloadUrl: '',
          releaseNotes: '',
        );
      }

      // 4. Find Asset for Current OS
      final String osSuffix = Platform.isWindows ? '_Windows.zip' : '_Linux.zip';
      String downloadUrl = '';
      
      final List assets = releaseData['assets'];
      for (var asset in assets) {
        final String name = asset['name'];
        if (name.endsWith(osSuffix)) {
          downloadUrl = asset['browser_download_url'];
          break;
        }
      }

      if (downloadUrl.isEmpty) {
        Logger.warning('No compatible asset found for this OS');
        return UpdateInfo(
          hasUpdate: false,
          latestVersion: latestVersion,
          downloadUrl: '',
          releaseNotes: '',
        );
      }

      return UpdateInfo(
        hasUpdate: true,
        latestVersion: latestVersion,
        downloadUrl: downloadUrl,
        releaseNotes: releaseData['body'] ?? '',
      );

    } catch (e) {
      Logger.error('Error checking for updates: $e');
      return UpdateInfo(
        hasUpdate: false,
        latestVersion: '',
        downloadUrl: '',
        releaseNotes: '',
      );
    }
  }

  bool _isNewerVersion(String current, String latest) {
    try {
      final cParts = current.split('.').map(int.parse).toList();
      final lParts = latest.split('.').map(int.parse).toList();

      for (int i = 0; i < 3; i++) {
        final c = i < cParts.length ? cParts[i] : 0;
        final l = i < lParts.length ? lParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
      return false;
    } catch (e) {
      Logger.error('Error comparing versions: $e');
      return false;
    }
  }

  Future<void> performUpdate(
    String downloadUrl, 
    Function(String status, double progress) onProgress
  ) async {
    try {
      onProgress('Downloading update...', 0.1);

      // 1. Download Zip
      final tempDir = await getTemporaryDirectory();
      final zipFile = File(path.join(tempDir.path, 'update.zip'));
      
      if (zipFile.existsSync()) zipFile.deleteSync();

      final request = await http.Client().send(http.Request('GET', Uri.parse(downloadUrl)));
      final totalBytes = request.contentLength ?? 1;
      int receivedBytes = 0;

      final sink = zipFile.openWrite();
      await request.stream.listen(
        (chunk) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          onProgress(
            'Downloading update...', 
            0.1 + (0.4 * (receivedBytes / totalBytes)) // 0.1 -> 0.5
          );
        },
      ).asFuture();
      await sink.close();

      onProgress('Preparing to install...', 0.6);

      // 2. Determine Install Directory and Executable
      final executablePath = Platform.resolvedExecutable;
      final installDir = File(executablePath).parent.path;

      Logger.info('Updating from $executablePath in $installDir');

      // 3. Create Update Script
      if (Platform.isWindows) {
        await _runWindowsUpdate(zipFile.path, installDir, executablePath, pid);
      } else if (Platform.isLinux) {
        await _runLinuxUpdate(zipFile.path, installDir, executablePath, pid);
      }

      onProgress('Restarting...', 1.0);
      exit(0); // Exit to allow script to run

    } catch (e) {
      Logger.error('Update failed: $e');
      throw e;
    }
  }

  Future<void> _runWindowsUpdate(
    String zipPath, 
    String installDir, 
    String exePath,
    int currentPid
  ) async {
    final scriptPath = path.join(path.dirname(zipPath), 'update_luyumi.bat');
    final script = File(scriptPath);

    // Using PowerShell to extract zip because 'tar' might not be available on older Windows 10
    // But 'tar' is standard on Win 10 (1803+). Let's use tar for simplicity, fallback to powershell if needed?
    // User said "vai usar a api do github para baixar", assumes modern env.
    // We will use a robust batch script.

    // Note: We need to wait for the process to exit.
    // timeout /t 2
    // tar -xf zip -C installDir
    // start exe

    final batContent = '''
@echo off
title Luyumi Updater
echo Waiting for Luyumi Launcher to close...
timeout /t 3 /nobreak >nul
taskkill /F /PID $currentPid >nul 2>&1

echo Updating Luyumi Launcher...
echo Extracting update...
tar -xf "$zipPath" -C "$installDir"

echo Update complete.
echo Restarting...
start "" "$exePath"
del "%~f0"
''';

    await script.writeAsString(batContent);

    // Run the script detached
    Process.start(
      'cmd.exe', 
      ['/c', scriptPath], 
      mode: ProcessStartMode.detached
    );
  }

  Future<void> _runLinuxUpdate(
    String zipPath, 
    String installDir, 
    String exePath,
    int currentPid
  ) async {
    final scriptPath = path.join(path.dirname(zipPath), 'update_luyumi.sh');
    final script = File(scriptPath);

    final shContent = '''
#!/bin/bash
echo "Waiting for Luyumi Launcher to close..."
sleep 3
kill -9 $currentPid 2>/dev/null

echo "Updating Luyumi Launcher..."
unzip -o "$zipPath" -d "$installDir"

echo "Setting permissions..."
chmod +x "$exePath"

echo "Restarting..."
"$exePath" &
rm "\$0"
''';

    await script.writeAsString(shContent);
    await Process.run('chmod', ['+x', scriptPath]);

    // Run the script detached
    Process.start(
      '/bin/bash', 
      [scriptPath], 
      mode: ProcessStartMode.detached
    );
  }
}
