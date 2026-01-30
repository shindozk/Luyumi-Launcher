import 'dart:io';
import 'package:path/path.dart' as path;
import 'logger.dart';

class BackendDiagnostics {
  /// Perform comprehensive backend diagnostics
  static Future<Map<String, dynamic>> diagnose() async {
    final diagnostics = <String, dynamic>{};

    try {
      // 1. Platform info
      diagnostics['platform'] = Platform.operatingSystem;
      diagnostics['isLinux'] = Platform.isLinux;
      diagnostics['isWindows'] = Platform.isWindows;
      diagnostics['isMacOS'] = Platform.isMacOS;

      // 2. Resolve paths
      final backendDir = await _resolveBackendDir();
      diagnostics['backendDir'] = backendDir;
      diagnostics['backendExists'] = await Directory(backendDir).exists();

      // 3. Check Python
      final pythonExe = await _resolvePythonPath();
      diagnostics['pythonExe'] = pythonExe;
      diagnostics['pythonExists'] = await File(pythonExe).exists();

      // 4. Python version
      try {
        final result = await Process.run(pythonExe, ['--version']);
        diagnostics['pythonVersion'] = result.stdout.toString().trim();
        diagnostics['pythonVersionStderr'] = result.stderr.toString().trim();
      } catch (e) {
        diagnostics['pythonVersionError'] = e.toString();
      }

      // 5. Check requirements.txt
      final requirementsPath = path.join(backendDir, 'requirements.txt');
      diagnostics['requirementsExists'] = await File(requirementsPath).exists();
      if (await File(requirementsPath).exists()) {
        diagnostics['requirementsContent'] =
            await File(requirementsPath).readAsString();
      }

      // 6. Check main.py
      final mainPyPath = path.join(backendDir, 'main.py');
      diagnostics['mainPyExists'] = await File(mainPyPath).exists();

      // 7. Check src directory
      final srcDir = path.join(backendDir, 'src');
      diagnostics['srcDirExists'] = await Directory(srcDir).exists();
      if (await Directory(srcDir).exists()) {
        final contents = await Directory(srcDir).list().toList();
        diagnostics['srcContents'] =
            contents.map((e) => e.path.split(Platform.pathSeparator).last).toList();
      }

      // 8. Test Python import (safe check)
      try {
        final testCode =
            'import sys; print(sys.executable); import fastapi; print("fastapi OK")';
        final result = await Process.run(
          pythonExe,
          ['-c', testCode],
        ).timeout(const Duration(seconds: 5));
        diagnostics['pythonImportTest'] = {
          'exitCode': result.exitCode,
          'stdout': result.stdout.toString().trim(),
          'stderr': result.stderr.toString().trim(),
        };
      } catch (e) {
        diagnostics['pythonImportTestError'] = e.toString();
      }

      // 9. Environment variables
      diagnostics['pythonPath'] = Platform.environment['PYTHONPATH'] ?? 'not set';
      diagnostics['path'] =
          Platform.environment['PATH']?.substring(0, 100) ?? 'not set';

      // 10. Check platform-specific issues
      if (Platform.isLinux) {
        diagnostics['linux'] = {
          'xdgSessionType': Platform.environment['XDG_SESSION_TYPE'],
          'waylandDisplay': Platform.environment['WAYLAND_DISPLAY'],
        };
      }

      diagnostics['success'] = true;
    } catch (e, stack) {
      diagnostics['success'] = false;
      diagnostics['error'] = e.toString();
      diagnostics['stackTrace'] = stack.toString();
    }

    return diagnostics;
  }

  /// Print diagnostics in readable format
  static Future<void> printDiagnostics() async {
    final diag = await diagnose();

    Logger.info('=== BACKEND DIAGNOSTICS ===');
    Logger.info('Platform: ${diag['platform']}');
    Logger.info('Backend Dir: ${diag['backendDir']}');
    Logger.info('Backend Exists: ${diag['backendExists']}');
    Logger.info('Python Exe: ${diag['pythonExe']}');
    Logger.info('Python Exists: ${diag['pythonExists']}');
    Logger.info('Python Version: ${diag['pythonVersion']}');
    Logger.info('Requirements Exists: ${diag['requirementsExists']}');
    Logger.info('Main.py Exists: ${diag['mainPyExists']}');
    Logger.info('Src Dir Exists: ${diag['srcDirExists']}');

    if (diag['pythonImportTest'] != null) {
      final test = diag['pythonImportTest'] as Map;
      Logger.info('Python Import Test Exit Code: ${test['exitCode']}');
      Logger.info('Python Import Test Output: ${test['stdout']}');
      if (test['stderr'].toString().isNotEmpty) {
        Logger.error('Python Import Test Error: ${test['stderr']}');
      }
    }

    Logger.info('========================');
  }

  // Copy of BackendManager methods for diagnostics
  static Future<String> _resolvePythonPath() async {
    final localPy = await _getLocalPythonExecutable();
    if (localPy != null) return localPy;

    try {
      String pathVar = Platform.environment['PATH'] ?? '';
      String pathSeparator = Platform.isWindows ? ';' : ':';
      List<String> paths = pathVar.split(pathSeparator);

      if (Platform.isWindows) {
        final localAppData = Platform.environment['LOCALAPPDATA'];
        if (localAppData != null) {
          paths.add(path.join(localAppData, 'Programs', 'Python', 'Python311'));
          paths.add(path.join(localAppData, 'Programs', 'Python', 'Python312'));
          paths.add(path.join(localAppData, 'Programs', 'Python', 'Python310'));
        }
      }

      String executableName = Platform.isWindows ? 'python.exe' : 'python3';

      for (String p in paths) {
        String fullPath = path.join(p, executableName);
        if (await File(fullPath).exists()) {
          return fullPath;
        }
      }
    } catch (e) {
      // Ignore
    }

    return Platform.isWindows ? 'python' : 'python3';
  }

  static Future<String?> _getLocalPythonExecutable() async {
    // Implementation similar to PythonInstaller
    // For now, return null to use system Python
    return null;
  }

  static Future<String> _resolveBackendDir() async {
    var dir = path.join(Directory.current.path, 'lib', 'backend');
    if (await File(path.join(dir, 'main.py')).exists()) {
      return dir;
    }

    final exeDir = path.dirname(Platform.resolvedExecutable);
    dir = path.join(exeDir, 'data', 'flutter_assets', 'lib', 'backend');
    if (await File(path.join(dir, 'main.py')).exists()) {
      return dir;
    }

    if (Platform.isLinux) {
      dir = path.join(exeDir, 'flutter_assets', 'lib', 'backend');
      if (await File(path.join(dir, 'main.py')).exists()) {
        return dir;
      }
    }

    dir = path.join(
      exeDir,
      '..',
      'Frameworks',
      'App.framework',
      'Resources',
      'flutter_assets',
      'lib',
      'backend',
    );
    if (await File(path.join(dir, 'main.py')).exists()) {
      return path.normalize(dir);
    }

    throw Exception(
      "Could not resolve backend directory. Checked standard paths.",
    );
  }
}
