import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _keyJavaPath = 'java_path';
  static const String _keyCustomJavaEnabled = 'custom_java_enabled';
  static const String _keyRamAllocation = 'ram_allocation';
  static const String _keyFullscreen = 'fullscreen';
  static const String _keyDiscordRpc = 'discord_rpc';
  static const String _keyLanguage = 'language';
  static const String _keyGpuPreference = 'gpu_preference';
  static const String _keyAlwaysOnTop = 'always_on_top';
  static const String _keyLastSessionDuration = 'last_session_duration';

  Future<String?> getJavaPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyJavaPath);
  }

  Future<void> setJavaPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyJavaPath, path);
  }

  Future<bool> getCustomJavaEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyCustomJavaEnabled) ?? false;
  }

  Future<void> setCustomJavaEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyCustomJavaEnabled, enabled);
  }

  Future<int> getRamAllocation() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyRamAllocation) ?? 4096;
  }

  Future<void> setRamAllocation(int mb) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyRamAllocation, mb);
  }

  Future<bool> getFullscreen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyFullscreen) ?? true;
  }

  Future<void> setFullscreen(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFullscreen, enabled);
  }

  Future<bool> getDiscordRpc() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDiscordRpc) ?? true;
  }

  Future<void> setDiscordRpc(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDiscordRpc, enabled);
  }

  Future<String?> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLanguage);
  }

  Future<void> setLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, lang);
  }

  Future<String> getGpuPreference() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyGpuPreference) ?? 'auto';
  }

  Future<void> setGpuPreference(String pref) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGpuPreference, pref);
  }

  Future<bool> getAlwaysOnTop() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAlwaysOnTop) ?? false;
  }

  Future<void> setAlwaysOnTop(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAlwaysOnTop, enabled);
  }

  Future<bool> getCloseLauncherOnStart() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('close_launcher_on_start') ?? false;
  }

  Future<void> setCloseLauncherOnStart(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('close_launcher_on_start', enabled);
  }

  Future<int> getLastSessionDuration() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyLastSessionDuration) ?? 0;
  }

  Future<void> setLastSessionDuration(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastSessionDuration, seconds);
  }

  Future<String> getActiveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('active_profile') ?? 'default';
  }

  Future<void> setActiveProfile(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_profile', profileId);
  }
}
