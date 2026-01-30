import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'backend_service.dart';
import '../utils/logger.dart';

class AuthResponse {
  final String identityToken;
  final String sessionToken;
  final String mode;
  final String? username;
  final String? uuid;

  AuthResponse({
    required this.identityToken,
    required this.sessionToken,
    required this.mode,
    this.username,
    this.uuid,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      identityToken: json['IdentityToken'] ?? json['identityToken'] ?? json['access_token'] ?? '',
      sessionToken: json['SessionToken'] ?? json['sessionToken'] ?? json['refresh_token'] ?? '',
      mode: json['mode'] ?? json['token_type'] ?? 'offline',
      username: json['username'],
      uuid: json['uuid'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'identityToken': identityToken,
      'sessionToken': sessionToken,
      'mode': mode,
      'username': username,
      'uuid': uuid,
    };
  }
}

class AuthService {
  static final AuthService _instance = AuthService._internal();

  factory AuthService() {
    return _instance;
  }

  AuthService._internal();

  /// Login with username and UUID
  Future<AuthResponse> login(String username, {String? uuid}) async {
    final effectiveUuid = uuid ?? const Uuid().v4();

    try {
      Logger.info('[AuthService] Attempting login for: $username');

      // Always use Backend Service for token generation to ensure valid EdDSA signatures
      // The backend has access to the persistent Ed25519 keys and serves the JWKS
      final data = await BackendService.login(username, effectiveUuid);

      final authResponse = AuthResponse.fromJson(data);

      await _saveSession(username, authResponse, uuid: effectiveUuid);
      Logger.info('[AuthService] ✓ Login successful for: $username');
      return authResponse;
    } catch (e) {
      Logger.error('[AuthService] Login failed: $e. Falling back to saved session if available.');
      final saved = await getSavedSession();
      if (saved != null && saved.username == username) {
        return saved;
      }
      throw Exception('Login failed and no saved session: $e');
    }
  }

  /// Logout user
  Future<void> logout() async {
    try {
      Logger.info('[AuthService] User logout');
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      Logger.error('[AuthService] Logout error: $e');
    }
  }

  /// Refresh session with refresh token
  Future<AuthResponse?> refreshSession() async {
    try {
      Logger.info('[AuthService] Refreshing session');
      
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refresh_token') ?? 
                           prefs.getString('session_token');

      if (refreshToken == null) return null;

      final data = await BackendService.post(
        '/api/auth/refresh',
        {'refresh_token': refreshToken},
      );

      if (data != null) {
        final username = prefs.getString('user_name') ?? 'unknown';
        final uuid = prefs.getString('user_uuid');

        final authResponse = AuthResponse.fromJson(data);
        await _saveSession(username, authResponse, uuid: uuid);
        return authResponse;
      }
      return null;
    } catch (e) {
      Logger.error('[AuthService] Refresh failed: $e');
      return null;
    }
  }

  /// Verify current session
  Future<bool> verifySession() async {
    try {
      final session = await getSavedSession();
      return session != null;
    } catch (e) {
      return false;
    }
  }

  Future<void> _saveSession(
    String username,
    AuthResponse auth, {
    required String? uuid,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', username);
    if (uuid != null) await prefs.setString('user_uuid', uuid);
    await prefs.setString('identity_token', auth.identityToken);
    await prefs.setString('session_token', auth.sessionToken);
    await prefs.setString('auth_mode', auth.mode);
    await prefs.setString('access_token', auth.identityToken);
    await prefs.setString('refresh_token', auth.sessionToken);
  }

  Future<AuthResponse?> getSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('user_name');
    final iToken = prefs.getString('identity_token');
    final sToken = prefs.getString('session_token');
    final mode = prefs.getString('auth_mode');
    final uuid = prefs.getString('user_uuid');

    if (username != null && iToken != null && sToken != null) {
      return AuthResponse(
        identityToken: iToken,
        sessionToken: sToken,
        mode: mode ?? 'offline',
        username: username,
        uuid: uuid,
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

  Future<Map<String, String>> generateOfflineSession(String username, [String? uuid]) async {
    final response = await login(username, uuid: uuid);
    return {
      'identityToken': response.identityToken,
      'sessionToken': response.sessionToken,
    };
  }

  Future<bool> isAuthenticated() async {
    final session = await getSavedSession();
    return session != null;
  }
}
