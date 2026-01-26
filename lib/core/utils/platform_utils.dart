import 'dart:io';
import 'package:process_run/shell.dart';

class PlatformUtils {
  static String getOs() {
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  static String getOsName() => getOs();

  static String getArch() {
    // Dart doesn't have a direct "arch" property in Platform, but we can infer or assume x64 for now
    // or check Platform.version which usually contains it.
    final version = Platform.version.toLowerCase();
    if (version.contains('arm64') || version.contains('aarch64')) {
      return 'arm64';
    }
    // Defaulting to x64 as most Hytale players are likely on x64
    return 'x64';
  }

  static bool isWaylandSession() {
    if (!Platform.isLinux) return false;
    final env = Platform.environment;
    final sessionType = env['XDG_SESSION_TYPE'];
    if (sessionType != null && sessionType.toLowerCase() == 'wayland') {
      return true;
    }
    if (env.containsKey('WAYLAND_DISPLAY')) {
      return true;
    }
    // Checking loginctl might be too complex/slow for simple check, skip for now unless needed
    return false;
  }

  static Map<String, String> setupWaylandEnvironment() {
    if (!Platform.isLinux) return {};
    if (!isWaylandSession()) return {};
    return {
      'SDL_VIDEODRIVER': 'wayland',
      'GDK_BACKEND': 'wayland',
      'QT_QPA_PLATFORM': 'wayland',
      'MOZ_ENABLE_WAYLAND': '1',
      '_JAVA_AWT_WM_NONREPARENTING': '1',
      'ELECTRON_OZONE_PLATFORM_HINT': 'wayland',
    };
  }

  static Future<GpuInfo> detectGpu() async {
    try {
      if (Platform.isLinux) return await _detectGpuLinux();
      if (Platform.isWindows) return await _detectGpuWindows();
      if (Platform.isMacOS) return await _detectGpuMac();
    } catch (e) {
      // Ignore errors
    }
    return GpuInfo(mode: 'integrated', vendor: 'intel', integratedName: 'Unknown');
  }

  static Future<GpuInfo> _detectGpuLinux() async {
    try {
      final result = await run('lspci -nn | grep "VGA\\|3D"', verbose: false);
      final output = result.outText;
      final lines = output.split('\n');
      String? integratedName;
      String? dedicatedName;
      bool hasNvidia = false;
      bool hasAmd = false;

      for (var line in lines) {
        final lower = line.toLowerCase();
        if (lower.contains('nvidia') || lower.contains('10de:')) {
          hasNvidia = true;
          dedicatedName = line.trim();
        } else if (lower.contains('amd') || lower.contains('radeon') || lower.contains('1002:')) {
          hasAmd = true;
          dedicatedName = line.trim();
        } else if (lower.contains('intel') || lower.contains('8086:')) {
          integratedName = line.trim();
        }
      }

      if (hasNvidia) {
        return GpuInfo(mode: 'dedicated', vendor: 'nvidia', integratedName: integratedName ?? 'Intel GPU', dedicatedName: dedicatedName);
      }
      if (hasAmd) {
        return GpuInfo(mode: 'dedicated', vendor: 'amd', integratedName: integratedName ?? 'Intel GPU', dedicatedName: dedicatedName);
      }
    } catch (_) {}
    return GpuInfo(mode: 'integrated', vendor: 'intel', integratedName: 'Intel GPU');
  }

  static Future<GpuInfo> _detectGpuWindows() async {
    try {
      final result = await run('wmic path win32_VideoController get name', verbose: false);
      final output = result.outText;
      final lines = output.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty && l.toLowerCase() != 'name').toList();
      
      String? integratedName;
      String? dedicatedName;
      bool hasNvidia = false;
      bool hasAmd = false;

      for (var line in lines) {
        final lower = line.toLowerCase();
        if (lower.contains('nvidia')) {
          hasNvidia = true;
          dedicatedName = line;
        } else if (lower.contains('amd') || lower.contains('radeon')) {
          hasAmd = true;
          dedicatedName = line;
        } else if (lower.contains('intel')) {
          integratedName = line;
        }
      }

      if (hasNvidia) {
        return GpuInfo(mode: 'dedicated', vendor: 'nvidia', integratedName: integratedName ?? 'Intel GPU', dedicatedName: dedicatedName);
      }
      if (hasAmd) {
        return GpuInfo(mode: 'dedicated', vendor: 'amd', integratedName: integratedName ?? 'Intel GPU', dedicatedName: dedicatedName);
      }
    } catch (_) {}
    return GpuInfo(mode: 'integrated', vendor: 'intel', integratedName: 'Intel GPU');
  }

  static Future<GpuInfo> _detectGpuMac() async {
    try {
      final result = await run('system_profiler SPDisplaysDataType', verbose: false);
      final output = result.outText;
      final lines = output.split('\n');
      
      String? integratedName;
      String? dedicatedName;
      bool hasNvidia = false;
      bool hasAmd = false;

      for (var line in lines) {
        if (line.contains('Chipset Model:')) {
          final gpuName = line.split('Chipset Model:').last.trim();
          final lower = gpuName.toLowerCase();
          if (lower.contains('nvidia')) {
            hasNvidia = true;
            dedicatedName = gpuName;
          } else if (lower.contains('amd') || lower.contains('radeon')) {
            hasAmd = true;
            dedicatedName = gpuName;
          } else {
            integratedName = gpuName;
          }
        }
      }

      if (hasNvidia) {
        return GpuInfo(mode: 'dedicated', vendor: 'nvidia', integratedName: integratedName ?? 'Integrated GPU', dedicatedName: dedicatedName);
      }
      if (hasAmd) {
        return GpuInfo(mode: 'dedicated', vendor: 'amd', integratedName: integratedName ?? 'Integrated GPU', dedicatedName: dedicatedName);
      }
    } catch (_) {}
    return GpuInfo(mode: 'integrated', vendor: 'intel', integratedName: 'Integrated GPU');
  }

  static Future<Map<String, String>> setupGpuEnvironment(String gpuPreference) async {
    if (!Platform.isLinux) return {};
    
    final detected = await detectGpu();
    final finalPreference = gpuPreference == 'auto' ? detected.mode : gpuPreference;
    
    final env = <String, String>{};
    if (finalPreference == 'dedicated') {
      env['DRI_PRIME'] = '1';
      if (detected.vendor == 'nvidia') {
        env['__NV_PRIME_RENDER_OFFLOAD'] = '1';
        env['__GLX_VENDOR_LIBRARY_NAME'] = 'nvidia';
        env['__GL_SHADER_DISK_CACHE'] = '1';
        env['__GL_SHADER_DISK_CACHE_PATH'] = '/tmp';
      }
    }
    return env;
  }

  static Future<void> openFolder(String path) async {
    if (!await Directory(path).exists()) {
      throw Exception('Path not found: $path');
    }

    if (Platform.isWindows) {
      await Process.run('explorer', [path]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [path]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [path]);
    }
  }
}

class GpuInfo {
  final String mode;
  final String vendor;
  final String integratedName;
  final String? dedicatedName;

  GpuInfo({
    required this.mode,
    required this.vendor,
    required this.integratedName,
    this.dedicatedName,
  });
}
