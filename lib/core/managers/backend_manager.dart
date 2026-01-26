import 'dart:io';
import 'package:path/path.dart' as path;
import '../utils/logger.dart';
import '../services/backend_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

class BackendManager {
  static Process? _backendProcess;

  /// Rebuild backend from TypeScript source
  static Future<void> rebuildBackend({
    Function(String, double)? onProgress,
  }) async {
    try {
      final backendSrcDir = path.join(Directory.current.path, 'lib', 'backend');
      
      // Check if source exists before attempting to rebuild
      if (!await Directory(backendSrcDir).exists()) {
        Logger.info('Backend source not found at $backendSrcDir. Skipping rebuild.');
        onProgress?.call('Backend source not found, skipping rebuild...', 1.0);
        return;
      }

      final assetsBackendDir = path.join(
        Directory.current.path,
        'lib',
        'assets',
        'backend',
      );

      final outputExe = path.join(
        assetsBackendDir,
        Platform.isWindows ? 'luyumi_backend.exe' : 'luyumi_backend',
      );

      // Resolve Bun executable
      String bunExe = 'bun';
      try {
        await Process.run(bunExe, ['--version'], runInShell: true);
      } catch (e) {
        // Fallback to local app data if bun is not in PATH
        if (Platform.isWindows) {
          final localAppData = Platform.environment['LOCALAPPDATA'];
          if (localAppData != null) {
            final possiblePath = path.join(
              localAppData,
              'bun',
              'bin',
              'bun.exe',
            );
            if (await File(possiblePath).exists()) {
              bunExe = possiblePath;
              Logger.info('Using Bun from explicit path: $bunExe');
            }
          }
        }
      }

      // IMPORTANT: Stop any running backend process first
      onProgress?.call('Stopping running backend...', 0.1);
      stop(); // Kill any existing backend process

      // Wait for process to fully terminate and release file lock
      await Future.delayed(const Duration(milliseconds: 500));

      // Delete old executable if exists
      onProgress?.call('Removing old backend...', 0.2);
      if (await File(outputExe).exists()) {
        try {
          await File(outputExe).delete();
          Logger.info('Deleted old backend executable');
        } catch (e) {
          // If we can't delete (file in use), force kill any lingering processes
          Logger.warning('Could not delete backend immediately: $e');

          if (Platform.isWindows) {
            // Force kill any process using the file
            try {
              await Process.run('taskkill', [
                '/F',
                '/IM',
                'luyumi_backend.exe',
              ], runInShell: true);
              await Future.delayed(const Duration(milliseconds: 1000));
              await File(outputExe).delete();
            } catch (killError) {
              Logger.error('Could not force kill backend: $killError');
              throw Exception(
                'Backend file is in use. Please close all instances of the launcher and try again.',
              );
            }
          } else {
            rethrow;
          }
        }
      }

      onProgress?.call('Installing backend dependencies...', 0.3);

      // Install dependencies first
      final installResult = await Process.run(
        bunExe,
        ['install'],
        workingDirectory: backendSrcDir,
        runInShell: true,
      );

      if (installResult.exitCode != 0) {
        Logger.warning('Bun install failed: ${installResult.stderr}');
      } else {
        Logger.info('Bun install complete: ${installResult.stdout}');
      }

      onProgress?.call('Compiling backend with Bun...', 0.6);

      // Compile backend using bun
      final compileResult = await Process.run(
        bunExe,
        [
          'build',
          '--compile',
          // '--minify', // Disable minification to debug "Cannot access 'G' before initialization"
          './src/index.ts',
          '--outfile',
          outputExe,
        ],
        workingDirectory: backendSrcDir,
        runInShell: true,
      );

      if (compileResult.exitCode != 0) {
        final error = compileResult.stderr.toString();
        Logger.error('Backend compilation failed: $error');
        throw Exception('Failed to compile backend: $error');
      }

      onProgress?.call('Backend compiled successfully!', 1.0);
      Logger.info('Backend compiled to: $outputExe');
      Logger.info('Compilation output: ${compileResult.stdout}');

      // Verify the executable was created
      if (!await File(outputExe).exists()) {
        throw Exception('Backend executable was not created');
      }
    } catch (e) {
      Logger.error('Failed to rebuild backend: $e');
      rethrow;
    }
  }

  static Future<void> init() async {
    if (await BackendService.isOnline()) {
      Logger.info("Backend is already running.");
      return;
    }

    Logger.info("Starting Luyumi Backend...");

    String? backendExecutablePath;

    // 1. Check for local dev executable FIRST (works in both debug and release for dev)
    final devExePath = path.join(
      Directory.current.path,
      'lib',
      'assets',
      'backend',
      Platform.isWindows ? 'luyumi_backend.exe' : 'luyumi_backend',
    );

    if (await File(devExePath).exists()) {
      backendExecutablePath = devExePath;
      Logger.info(
        "Found backend executable in dev assets: $backendExecutablePath",
      );
    }

    // 2. Try to load from bundled assets (for release builds)
    if (backendExecutablePath == null) {
      try {
        Directory appDocDir;
        if (Platform.isWindows) {
          final appData = Platform.environment['APPDATA'];
          if (appData != null) {
            appDocDir = Directory(path.join(appData, 'LuyumiLauncher'));
          } else {
            appDocDir = await getApplicationSupportDirectory();
          }
        } else {
          appDocDir = await getApplicationSupportDirectory();
        }

        final backendDir = Directory(path.join(appDocDir.path, 'backend'));
        if (!backendDir.existsSync()) {
          backendDir.createSync(recursive: true);
        }

        final exeName = Platform.isWindows
            ? 'luyumi_backend.exe'
            : 'luyumi_backend';
        final exeFile = File(path.join(backendDir.path, exeName));

        try {
          final byteData = await rootBundle.load('lib/assets/backend/$exeName');
          final bytes = byteData.buffer.asUint8List();
          await exeFile.writeAsBytes(bytes);
          if (!Platform.isWindows) {
            await Process.run('chmod', ['+x', exeFile.path]);
          }
          backendExecutablePath = exeFile.path;
          Logger.info("Extracted backend to $backendExecutablePath");
        } catch (e) {
          Logger.warning("Could not load backend asset from bundle: $e");
        }
      } catch (e) {
        Logger.error("Error setting up backend from assets: $e");
      }
    }

    // 3. Fallback: Run with bun from source (development only)
    if (backendExecutablePath == null) {
      String backendPath = path.join(Directory.current.path, 'lib', 'backend');
      if (await Directory(backendPath).exists()) {
        try {
          // Resolve Bun executable
          String bunExe = 'bun';
          try {
            await Process.run(bunExe, ['--version'], runInShell: true);
          } catch (e) {
            if (Platform.isWindows) {
              final localAppData = Platform.environment['LOCALAPPDATA'];
              if (localAppData != null) {
                final possiblePath = path.join(
                  localAppData,
                  'bun',
                  'bin',
                  'bun.exe',
                );
                if (await File(possiblePath).exists()) {
                  bunExe = possiblePath;
                }
              }
            }
          }

          Logger.info(
            "Trying to run backend with '$bunExe' from source in $backendPath",
          );
          await Process.run(bunExe, ['--version']);

          // Ensure dependencies are installed before running
          Logger.info("Installing backend dependencies...");
          await Process.run(
            bunExe,
            ['install'],
            workingDirectory: backendPath,
            runInShell: true,
          );

          _backendProcess = await Process.start(
            bunExe,
            ['run', 'src/index.ts'],
            workingDirectory: backendPath,
            runInShell: true,
          );

          _backendProcess!.stdout
              .transform(const SystemEncoding().decoder)
              .listen((data) {
                Logger.info(data, 'Backend');
              });
          _backendProcess!.stderr
              .transform(const SystemEncoding().decoder)
              .listen((data) {
                Logger.error(data, null, null, 'Backend');
              });

          _waitForBackend();
          return;
        } catch (e) {
          Logger.warning("Bun not found or failed to start: $e");
        }
      }
    }

    // 3. Run the executable if found
    if (backendExecutablePath != null) {
      Logger.info("Spawning backend process: $backendExecutablePath");
      try {
        _backendProcess = await Process.start(
          backendExecutablePath,
          [],
          runInShell: false,
        );

        // Capture logs for executable too
        _backendProcess!.stdout
            .transform(const SystemEncoding().decoder)
            .listen((data) {
              Logger.info(data, 'Backend');
            });
        _backendProcess!.stderr
            .transform(const SystemEncoding().decoder)
            .listen((data) {
              // Treat stderr as info unless it contains specific error keywords
              if (data.toLowerCase().contains('error') || 
                  data.toLowerCase().contains('exception') ||
                  data.toLowerCase().contains('fatal')) {
                Logger.error(data, null, null, 'Backend');
              } else {
                Logger.info(data, 'Backend [STDERR]');
              }
            });

        _waitForBackend();
      } catch (e) {
        Logger.error("Failed to start backend executable: $e");
      }
    } else {
      Logger.error("Could not find any way to start the backend.");
      throw Exception("Could not find any way to start the backend. Please ensure the backend executable is bundled.");
    }
  }

  static Future<void> _waitForBackend() async {
    int retries = 0;
    while (retries < 20) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (await BackendService.isOnline()) {
        Logger.info("Backend started successfully.");
        return;
      }
      retries++;
    }
    Logger.error("Backend failed to start after 10 seconds.");
    throw Exception("Backend failed to start after 10 seconds.");
  }

  static void stop() {
    if (_backendProcess != null) {
      Logger.info("Stopping backend process...");
      try {
        // Kill the process tree (important for Windows to kill all child processes)
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
        Process.runSync('taskkill', [
          '/F', // Force termination
          '/IM',
          'luyumi_backend.exe',
        ]);
        Logger.info("Killed any lingering luyumi_backend.exe processes");
      } catch (e) {
        // It's okay if there are no processes to kill
      }
    }
  }
}
