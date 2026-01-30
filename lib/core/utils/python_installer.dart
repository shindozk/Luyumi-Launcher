import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../utils/logger.dart';
import '../utils/file_manager.dart';

class PythonInstaller {
  // Using Python 3.11.9 as a stable base
  static const String pythonVersion = '3.11.9';
  static const String pythonWindowsDownloadUrl =
      'https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe';
  static const String pythonLinuxDownloadUrl = 
      'https://github.com/indygreg/python-build-standalone/releases/download/20240415/cpython-3.11.9+20240415-x86_64-unknown-linux-gnu-install_only.tar.gz';

  /// Get local python executable path if installed
  static Future<String?> getLocalPythonExecutable() async {
    if (Platform.isLinux) {
      try {
        final appDir = await getApplicationSupportDirectory();
        final pythonPath = path.join(appDir.path, 'python', 'bin', 'python3');
        if (await File(pythonPath).exists()) {
          return pythonPath;
        }
      } catch (e) {
        // Ignore
      }
    }
    return null;
  }

  /// Check if Python is installed and accessible
  static Future<bool> isPythonInstalled() async {
    try {
      // 1. Check local install first
      final localPy = await getLocalPythonExecutable();
      if (localPy != null) {
        Logger.info("Local Python found: $localPy");
        return true;
      }

      // Try 'python' first
      var result = await Process.run('python', ['--version'], runInShell: true);
      if (result.exitCode == 0) {
        Logger.info("Python found: ${result.stdout.toString().trim()}");
        return true;
      }
      
      // Try 'python3' (mac/linux mostly, but sometimes windows via wrappers)
      result = await Process.run('python3', ['--version'], runInShell: true);
      if (result.exitCode == 0) {
        Logger.info("Python3 found: ${result.stdout.toString().trim()}");
        return true;
      }
      
      // Try 'py' launcher on Windows
      if (Platform.isWindows) {
         result = await Process.run('py', ['--version'], runInShell: true);
         if (result.exitCode == 0) {
           Logger.info("Python Launcher found: ${result.stdout.toString().trim()}");
           return true;
         }
      }
      
    } catch (e) {
      Logger.info("Python check failed: $e");
    }
    return false;
  }

  /// Install Python
  static Future<bool> installPython({Function(String, double)? onProgress}) async {
    if (Platform.isLinux) {
      return _installLinux(onProgress: onProgress);
    }

    if (!Platform.isWindows) {
      Logger.error("Auto-install is only supported on Windows and Linux");
      return false;
    }

    // Windows Installation Logic
    try {
      onProgress?.call("Downloading Python installer...", 0.1);

      // Create temp directory for download
      final tempDir = Directory.systemTemp.createTempSync('python_install_');
      final installerPath = path.join(tempDir.path, 'python_installer.exe');

      onProgress?.call("Downloading Python $pythonVersion...", 0.3);
      await FileManager.downloadFile(
        pythonWindowsDownloadUrl,
        installerPath,
        progress: (msg, prog) => onProgress?.call(msg, 0.3 + (prog * 0.4)),
      );

      onProgress?.call("Installing Python (this may take a while)...", 0.7);

      // Run installer silently
      // /quiet = no UI
      // InstallAllUsers=0 = install for current user only (no admin needed usually)
      // PrependPath=1 = add to PATH
      // Include_test=0 = skip test suite (save space)
      // Include_tcltk=0 = skip IDLE/tk (save space)
      // Include_doc=0 = skip docs (save space)
      // Include_pip=1 = ensure pip is installed (default is 1 but being explicit helps)
      final installResult = await Process.run(
        installerPath,
        [
          '/quiet',
          'InstallAllUsers=0',
          'PrependPath=1',
          'Include_test=0',
          'Include_tcltk=0',
          'Include_doc=0',
          'Include_launcher=1',
          'Include_pip=1'
        ],
        runInShell: true,
      );

      if (installResult.exitCode != 0) {
        Logger.error("Failed to install Python: ${installResult.exitCode} ${installResult.stderr}");
        // Try to delete temp file
        try { await File(installerPath).delete(); } catch (_) {}
        return false;
      }

      onProgress?.call("Python installed successfully!", 0.9);
      Logger.info("Python installer finished.");
      
      // Clean up
      try { await tempDir.delete(recursive: true); } catch (_) {}

      // Verify installation - might fail immediately due to PATH update delay
      return true; 
    } catch (e) {
      Logger.error("Failed to install Python: $e");
      return false;
    }
  }

  static Future<bool> _installLinux({Function(String, double)? onProgress}) async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final pythonDir = Directory(path.join(appDir.path, 'python'));
      
      if (await pythonDir.exists()) {
         await pythonDir.delete(recursive: true);
      }
      
      onProgress?.call("Downloading Python standalone...", 0.1);
      
      final tempDir = Directory.systemTemp.createTempSync('python_linux_');
      final tarPath = path.join(tempDir.path, 'python.tar.gz');
      
      await FileManager.downloadFile(
        pythonLinuxDownloadUrl, 
        tarPath, 
        progress: (msg, p) => onProgress?.call(msg, 0.1 + (p * 0.5))
      );
      
      onProgress?.call("Extracting Python...", 0.7);
      
      if (!await appDir.exists()) {
        await appDir.create(recursive: true);
      }
      
      // Extract using tar
      final result = await Process.run(
        'tar', 
        ['-xzf', tarPath, '-C', appDir.path],
        runInShell: true
      );
      
      if (result.exitCode != 0) {
         throw Exception("Failed to extract python: ${result.stderr}");
      }
      
      // Verify
      final pythonBin = path.join(appDir.path, 'python', 'bin', 'python3');
      if (await File(pythonBin).exists()) {
         // Ensure +x
         await Process.run('chmod', ['+x', pythonBin]);
      } else {
         throw Exception("Python binary not found at $pythonBin");
      }
      
      onProgress?.call("Python installed successfully!", 1.0);
      
      try { await tempDir.delete(recursive: true); } catch(_) {}
      
      return true;
      
    } catch (e) {
      Logger.error("Linux Python install failed: $e");
      return false;
    }
  }
}
