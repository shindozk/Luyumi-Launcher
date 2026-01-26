import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'backend_service.dart';
import '../utils/logger.dart';

class AuthResponse {
  final String identityToken;
  final String sessionToken;
  final String mode;

  AuthResponse({
    required this.identityToken,
    required this.sessionToken,
    required this.mode,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      identityToken: json['IdentityToken'] ?? json['identityToken'] ?? '',
      sessionToken: json['SessionToken'] ?? json['sessionToken'] ?? '',
      mode: json['mode'] ?? 'offline',
    );
  }
}

class AuthService {
  Future<AuthResponse> login(String username, {String? uuid}) async {
    final effectiveUuid = uuid ?? const Uuid().v4();

    try {
      // Delegate to Backend Service (which handles token generation)
      final data = await BackendService.login(username, effectiveUuid);
      
      final authResponse = AuthResponse(
        identityToken: data['IdentityToken'] ?? data['identityToken'],
        sessionToken: data['SessionToken'] ?? data['sessionToken'],
        mode: 'backend',
      );
      
      await _saveSession(username, authResponse, uuid: effectiveUuid);
      return authResponse;
    } catch (e) {
      Logger.error('Login failed: $e');
      throw Exception('Login failed: $e');
    }
  }

  Future<void> _saveSession(String username, AuthResponse auth, {required String uuid}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', username);
    await prefs.setString('user_uuid', uuid);
    await prefs.setString('identity_token', auth.identityToken);
    await prefs.setString('session_token', auth.sessionToken);
    await prefs.setString('auth_mode', auth.mode);
  }

  Future<AuthResponse?> getSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('user_name');
    final iToken = prefs.getString('identity_token');
    final sToken = prefs.getString('session_token');
    final mode = prefs.getString('auth_mode');

    if (username != null && iToken != null && sToken != null) {
      return AuthResponse(
        identityToken: iToken,
        sessionToken: sToken,
        mode: mode ?? 'offline',
      );
    }
    return null;
  }

  Future<String?> getSavedUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_name');
  }

  Future<String?> getSavedUuid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_uuid');
  }

  Future<void> saveUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', username);
  }

  Future<void> saveUuid(String uuid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_uuid', uuid);
  }
}
