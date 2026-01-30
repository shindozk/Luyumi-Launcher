import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/logger.dart';
import '../services/backend_service.dart';
import '../utils/python_installer.dart';

class BackendManager {
  static Process? _backendProcess;

  /// Resolve Python executable path
  static Future<String> _resolvePythonPath() async {
    // 0. Check for local installation via PythonInstaller
    final localPy = await PythonInstaller.getLocalPythonExecutable();
    if (localPy != null) {
      Logger.info("Using local Python: $localPy");
      return localPy;
    }

    // 1. Try to find python in PATH environment variable manually
    try {
      String pathVar = Platform.environment['PATH'] ?? '';
      String pathSeparator = Platform.isWindows ? ';' : ':';
      List<String> paths = pathVar.split(pathSeparator);

      // Add common Windows Python installation paths to search list if on Windows
      if (Platform.isWindows) {
        final localAppData = Platform.environment['LOCALAPPDATA'];
        if (localAppData != null) {
          // Check Python 3.11 specifically (what we install)
          paths.add(path.join(localAppData, 'Programs', 'Python', 'Python311'));
          // Check generic Python folder just in case
          paths.add(path.join(localAppData, 'Programs', 'Python', 'Python312'));
          paths.add(path.join(localAppData, 'Programs', 'Python', 'Python310'));
        }
      }

      String executableName = Platform.isWindows ? 'python.exe' : 'python3';

      // Also try just 'python' on non-windows
      if (!Platform.isWindows) {
        // check for python3 first
      }

      for (String p in paths) {
        String fullPath = path.join(p, executableName);
        if (await File(fullPath).exists()) {
          return fullPath;
        }
      }
    } catch (e) {
      // Ignore
    }

    // 2. Last resort default
    return Platform.isWindows ? 'python' : 'python3';
  }

  /// Helper to find backend directory in both Debug and Release modes
  static Future<String> _resolveBackendDir() async {
    // 1. Debug/Dev: 'lib/backend' in current directory
    var dir = path.join(Directory.current.path, 'lib', 'backend');
    if (await File(path.join(dir, 'main.py')).exists()) {
      return dir;
    }

    // 2. Release (Windows & Linux):
    // Standard Flutter build structure puts 'data/flutter_assets' next to the executable.
    final exeDir = path.dirname(Platform.resolvedExecutable);

    // Windows & Linux standard path
    dir = path.join(exeDir, 'data', 'flutter_assets', 'lib', 'backend');
    if (await File(path.join(dir, 'main.py')).exists()) {
      return dir;
    }

    // 3. Linux Specific (Potential variations)
    // Sometimes assets might be in a 'lib' subfolder or similar if packaged differently
    if (Platform.isLinux) {
      // Check for 'flutter_assets/lib/backend' directly in exeDir (non-standard but possible)
      dir = path.join(exeDir, 'flutter_assets', 'lib', 'backend');
      if (await File(path.join(dir, 'main.py')).exists()) {
        return dir;
      }
    }

    // 4. Release (macOS): 'Contents/Frameworks/App.framework/Resources/flutter_assets/lib/backend'
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

  /// Install backend dependencies (pip install -r requirements.txt)
  static Future<void> installDependencies({
    Function(String, double)? onProgress,
  }) async {
    try {
      final backendSrcDir = await _resolveBackendDir();

      // Check if source exists (redundant with _resolveBackendDir but keeps logic safe)
      if (!await Directory(backendSrcDir).exists()) {
        Logger.info(
          'Backend source not found at $backendSrcDir. Skipping dependency check.',
        );
        onProgress?.call('Backend source not found...', 1.0);
        return;
      }

      final pythonExe = await _resolvePythonPath();

      // IMPORTANT: Stop any running backend process first
      onProgress?.call('Stopping running backend...', 0.1);
      stop();

      await Future.delayed(const Duration(milliseconds: 500));

      onProgress?.call('Installing backend dependencies...', 0.3);

      // Check if requirements.txt exists
      final requirementsFile = File(path.join(backendSrcDir, 'requirements.txt'));
      if (!await requirementsFile.exists()) {
        Logger.warning('requirements.txt not found at $backendSrcDir');
        onProgress?.call('Backend ready to run (no dependencies)!', 1.0);
        return;
      }

      // Install dependencies with better error handling
      ProcessResult installResult;
      try {
        installResult = await Process.run(
          pythonExe,
          ['-m', 'pip', 'install', '--upgrade', 'pip'],
          workingDirectory: backendSrcDir,
          runInShell: Platform.isLinux ? true : false,
        ).timeout(const Duration(seconds: 60));

        Logger.info('Pip upgrade: ${installResult.stdout}');
        if (installResult.exitCode != 0) {
          Logger.warning('Pip upgrade stderr: ${installResult.stderr}');
        }
      } catch (e) {
        Logger.warning("Pip upgrade failed: $e");
      }

      // Install requirements
      try {
        installResult = await Process.run(
          pythonExe,
          ['-m', 'pip', 'install', '-r', 'requirements.txt'],
          workingDirectory: backendSrcDir,
          runInShell: Platform.isLinux ? true : false,
        ).timeout(const Duration(minutes: 5));
      } catch (e) {
        Logger.warning(
          "Pip install with runInShell failed ($e). Trying without shell...",
        );
        installResult = await Process.run(
          pythonExe,
          ['-m', 'pip', 'install', '-r', 'requirements.txt'],
          workingDirectory: backendSrcDir,
          runInShell: false,
        );
      }

      if (installResult.exitCode != 0) {
        Logger.warning('Pip install stderr: ${installResult.stderr}');
        Logger.warning('Pip install stdout: ${installResult.stdout}');
      } else {
        Logger.info('Pip install complete');
      }

      onProgress?.call('Backend ready to run (Python)!', 1.0);
    } catch (e) {
      Logger.error('Failed to prepare backend: $e');
      rethrow;
    }
  }

  static Future<void> init() async {
    if (await BackendService.isOnline()) {
      Logger.info("Backend is already running.");
      return;
    }

    Logger.info("Starting Luyumi Backend (Python)...");

    try {
      final pythonExe = await _resolvePythonPath();
      Logger.info("Resolved Python executable: $pythonExe");

      final backendSrcDir = await _resolveBackendDir();
      Logger.info("Resolved backend directory: $backendSrcDir");

      final mainPyPath = 'main.py';
      final fullMainPyPath = path.join(backendSrcDir, mainPyPath);

      if (!await File(fullMainPyPath).exists()) {
        throw Exception('Backend entry point not found at $fullMainPyPath');
      }
      Logger.info("Backend main.py found at: $fullMainPyPath");

      Logger.info(
        "Spawning Python process: $pythonExe $mainPyPath in $backendSrcDir",
      );

      // Buffer for startup logs to help debugging
      final StringBuffer startupLogs = StringBuffer();

      // Prepare environment variables for backend
      final env = Map<String, String>.from(Platform.environment);

      // Add CurseForge API key from .env if available
      String? curseforgeKey;
      try {
        curseforgeKey = dotenv.env['CURSEFORGE_API_KEY'];
      } catch (_) {
        // dotenv might not be initialized if .env file is missing
      }

      // Fallback to compile-time variables (secure for release)
      if (curseforgeKey == null || curseforgeKey.isEmpty) {
        const envKey = String.fromEnvironment('CURSEFORGE_API_KEY');
        if (envKey.isNotEmpty) {
          curseforgeKey = envKey;
        }
      }

      if (curseforgeKey != null && curseforgeKey.isNotEmpty) {
        env['CURSEFORGE_API_KEY'] = curseforgeKey;
        Logger.info("CurseForge API key loaded");
      } else if (env.containsKey('CURSEFORGE_API_KEY') && env['CURSEFORGE_API_KEY']!.isNotEmpty) {
        Logger.info("CurseForge API key found in system environment");
      } else {
        Logger.warning(
          "CurseForge API key not found - mod search will not work",
        );
      }

      // Ensure PYTHONPATH includes the backend directory
      final currentPythonPath = env['PYTHONPATH'] ?? '';
      env['PYTHONPATH'] = currentPythonPath.isEmpty
          ? backendSrcDir
          : '$backendSrcDir${Platform.isWindows ? ';' : ':'}$currentPythonPath';
      Logger.info("PYTHONPATH set to: ${env['PYTHONPATH']}");

      // On Linux, use runInShell=true for better error handling
      // This ensures Python errors are properly captured
      final runInShell = Platform.isLinux;
      Logger.info("Starting backend with runInShell=$runInShell");

      // Strictly execute 'python main.py' without shell to avoid CMD window
      // User requested: "use somente o comando python main.py"
      // Added '-u' for unbuffered output to catch errors immediately
      _backendProcess =
          await Process.start(
            pythonExe,
            ['-u', mainPyPath],
            workingDirectory: backendSrcDir,
            runInShell: runInShell,
            mode: ProcessStartMode.normal,
            environment: env,
          ).timeout(
            const Duration(seconds: 5),
            onTimeout: () =>
                throw Exception('Backend process failed to start (timeout)'),
          );

      // Log stdout/stderr and buffer them
      _backendProcess!.stdout.listen((data) {
        final log = String.fromCharCodes(data).trim();
        if (log.isNotEmpty) {
          Logger.info('[Backend] $log');
          if (startupLogs.length < 3000) startupLogs.writeln(log);
        }
      });

      _backendProcess!.stderr.listen((data) {
        final log = String.fromCharCodes(data).trim();
        if (log.isNotEmpty) {
          Logger.error('[Backend] $log');
          if (startupLogs.length < 3000) startupLogs.writeln(log);
        }
      });

      // Check if process exits immediately
      int? exitCode;
      _backendProcess!.exitCode.then((code) {
        exitCode = code;
        if (code != 0) {
          Logger.error("Backend process exited unexpectedly with code: $code");
        } else {
          Logger.info("Backend process exited cleanly.");
        }
        // Don't nullify _backendProcess yet to allow reading logs
      });

      Logger.info("Backend process started with PID: ${_backendProcess!.pid}");

      // Wait for health check
      int retries = 0;
      while (retries < 20) {
        // Increased retries to 10s
        if (exitCode != null) {
          // Log which Python was used for debugging
          Logger.error("Backend process exit code: $exitCode");
          Logger.error("Python executable: $pythonExe");
          Logger.error("Backend directory: $backendSrcDir");
          Logger.error("Working directory: $backendSrcDir");

          // Add hint about common Linux issues
          if (Platform.isLinux && startupLogs.toString().isEmpty) {
            Logger.error("No startup logs captured - common causes:");
            Logger.error("  1. Python module import failed (check requirements.txt)");
            Logger.error("  2. Missing dependencies (pip install -r requirements.txt)");
            Logger.error("  3. Python version mismatch (need 3.8+)");
            Logger.error("  4. File permissions issue");
          }

          throw Exception(
            "Backend exited early (Code: $exitCode). Logs:\n$startupLogs",
          );
        }

        await Future.delayed(const Duration(milliseconds: 500));
        if (await BackendService.isOnline()) {
          Logger.info("Backend is online!");
          return;
        }
        retries++;
      }

      throw Exception(
        "Backend started but failed to respond (Timeout). Logs:\n$startupLogs",
      );
    } catch (e) {
      Logger.error("Failed to start backend process: $e");
      rethrow;
    }
  }

  static void stop() {
    if (_backendProcess != null) {
      Logger.info("Stopping backend process...");
      try {
        _backendProcess!.kill(ProcessSignal.sigkill);
        Logger.info("Backend process killed with SIGKILL");
      } catch (e) {
        Logger.warning("Error killing backend process: $e");
      }
      _backendProcess = null;
    }

    // Also try to kill any lingering backend processes on Windows
    if (Platform.isWindows) {
      try {
        // Kill python processes might be too aggressive if user is a dev,
        // but for a launcher app, we might need to be specific.
        // Ideally we track PIDs.
        // For now, let's just rely on the object kill.
        // If we really need to force kill, we should find children.
      } catch (e) {
        // Ignore
      }
    }
  }
}
