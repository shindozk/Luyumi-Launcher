import 'dart:io';
import 'package:path/path.dart' as path;
import '../utils/logger.dart';
import '../utils/file_manager.dart';

class BunInstaller {
  static const String bunVersion = '1.0.0';
  static const String bunWindowsDownloadUrl =
      'https://github.com/oven-sh/bun/releases/latest/download/bun-windows-x64.zip';

  /// Check if Bun is installed and accessible
  static Future<bool> isBunInstalled() async {
    try {
      final result = await Process.run('bun', ['--version'], runInShell: true);
      if (result.exitCode == 0) {
        final version = result.stdout.toString().trim();
        Logger.info("Bun is installed: $version");
        return true;
      }
    } catch (e) {
      Logger.info("Bun not found in PATH: $e");
    }
    return false;
  }

  /// Install Bun on Windows
  static Future<bool> installBun({Function(String, double)? onProgress}) async {
    if (!Platform.isWindows) {
      Logger.error("Auto-install is only supported on Windows");
      return false;
    }

    try {
      onProgress?.call("Downloading Bun installer...", 0.1);

      // Create temp directory for download
      final tempDir = Directory.systemTemp.createTempSync('bun_install_');
      final zipPath = path.join(tempDir.path, 'bun.zip');

      onProgress?.call("Downloading Bun...", 0.3);
      await FileManager.downloadFile(
        bunWindowsDownloadUrl,
        zipPath,
        progress: (msg, prog) => onProgress?.call(msg, 0.3 + (prog * 0.4)),
      );

      onProgress?.call("Extracting Bun...", 0.7);

      // Use PowerShell to extract zip
      final extractDir = path.join(tempDir.path, 'bun_extracted');
      await Directory(extractDir).create();

      final extractResult = await Process.run('powershell', [
        '-Command',
        'Expand-Archive -Path "$zipPath" -DestinationPath "$extractDir" -Force',
      ], runInShell: true);

      if (extractResult.exitCode != 0) {
        Logger.error("Failed to extract Bun: ${extractResult.stderr}");
        return false;
      }

      onProgress?.call("Installing Bun to system...", 0.85);

      // Find bun.exe in extracted files
      final bunExe = await _findBunExe(extractDir);
      if (bunExe == null) {
        Logger.error("Could not find bun.exe in extracted files");
        return false;
      }

      // Install to %LOCALAPPDATA%\bun\bin
      final localAppData = Platform.environment['LOCALAPPDATA'];
      if (localAppData == null) {
        Logger.error("LOCALAPPDATA not found");
        return false;
      }

      final bunInstallDir = path.join(localAppData, 'bun', 'bin');
      await Directory(bunInstallDir).create(recursive: true);

      final bunInstallPath = path.join(bunInstallDir, 'bun.exe');
      await File(bunExe).copy(bunInstallPath);

      onProgress?.call("Adding Bun to PATH...", 0.95);

      // Add to PATH using PowerShell
      await _addToPath(bunInstallDir);

      // Clean up temp directory
      await tempDir.delete(recursive: true);

      onProgress?.call("Bun installed successfully!", 1.0);
      Logger.info("Bun installed to: $bunInstallPath");

      return await isBunInstalled();
    } catch (e) {
      Logger.error("Failed to install Bun: $e");
      return false;
    }
  }

  static Future<String?> _findBunExe(String directory) async {
    final dir = Directory(directory);
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('bun.exe')) {
        return entity.path;
      }
    }
    return null;
  }

  static Future<void> _addToPath(String directory) async {
    try {
      // Get current user PATH
      final getPathResult = await Process.run('powershell', [
        '-Command',
        '[Environment]::GetEnvironmentVariable("Path", "User")',
      ], runInShell: true);

      final currentPath = getPathResult.stdout.toString().trim();

      // Check if already in PATH
      if (currentPath.contains(directory)) {
        Logger.info("Bun directory already in PATH");
        return;
      }

      // Add to PATH
      final newPath = currentPath.isEmpty
          ? directory
          : '$currentPath;$directory';

      await Process.run('powershell', [
        '-Command',
        '[Environment]::SetEnvironmentVariable("Path", "$newPath", "User")',
      ], runInShell: true);

      Logger.info("Added Bun to PATH");
    } catch (e) {
      Logger.warning("Failed to add Bun to PATH: $e");
    }
  }

  /// Get Bun executable path
  static Future<String?> getBunPath() async {
    try {
      final result = await Process.run('where', ['bun'], runInShell: true);
      if (result.exitCode == 0) {
        return result.stdout.toString().split('\n').first.trim();
      }
    } catch (e) {
      Logger.warning("Could not locate bun executable: $e");
    }
    return null;
  }
}
