import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../utils/logger.dart';

class UserService {
  static const String _baseUrl = 'http://localhost:8080/api';
  static String? _accessToken;
  static String? _refreshToken;

  /// Initialize - load tokens from storage
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
    _refreshToken = prefs.getString('refresh_token');
  }

  /// Save tokens to storage
  static Future<void> _saveTokens(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  /// Clear stored tokens
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    _accessToken = null;
    _refreshToken = null;
  }

  /// Get current access token
  static String? getAccessToken() => _accessToken;

  /// Login user with username and password
  static Future<Map<String, dynamic>?> login(
    String username,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          // Save tokens
          await _saveTokens(
            data['access_token'] ?? '',
            data['refresh_token'] ?? '',
          );
          Logger.info('[UserService] Login successful for: $username');
          return data['user'];
        }
      }

      if (response.statusCode == 429) {
        Logger.warning('[UserService] Rate limit exceeded for: $username');
        return null;
      }

      if (response.statusCode == 401) {
        Logger.warning('[UserService] Invalid credentials for: $username');
        return null;
      }

      Logger.error(
        '[UserService] Login failed: ${response.statusCode} - ${response.body}',
      );
      return null;
    } catch (e) {
      Logger.error('[UserService] Login error: $e');
      return null;
    }
  }

  /// Register new user
  static Future<Map<String, dynamic>> register(
    String username,
    String email,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        Logger.info('[UserService] Registration successful for: $username');
        return {'success': true, 'message': data['message']};
      }

      if (response.statusCode == 400) {
        Logger.warning('[UserService] Registration failed: ${data['error']}');
        return {'success': false, 'error': data['error']};
      }

      Logger.error(
        '[UserService] Registration failed: ${response.statusCode}',
      );
      return {'success': false, 'error': 'Registration failed'};
    } catch (e) {
      Logger.error('[UserService] Registration error: $e');
      return {'success': false, 'error': 'Registration error: $e'};
    }
  }

  /// Get user information
  static Future<Map<String, dynamic>?> getUser(String username) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/auth/user/$username'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          Logger.info('[UserService] Retrieved user: $username');
          return data['user'];
        }
      }

      if (response.statusCode == 404) {
        Logger.warning('[UserService] User not found: $username');
        return null;
      }

      Logger.error('[UserService] Get user failed: ${response.statusCode}');
      return null;
    } catch (e) {
      Logger.error('[UserService] Get user error: $e');
      return null;
    }
  }

  /// Update user bio
  static Future<bool> updateBio(String username, String bio) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/auth/user/bio'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'bio': bio,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          Logger.info('[UserService] Bio updated for: $username');
          return true;
        }
      }

      Logger.error('[UserService] Update bio failed: ${response.statusCode}');
      return false;
    } catch (e) {
      Logger.error('[UserService] Update bio error: $e');
      return false;
    }
  }

  /// Update user avatar
  static Future<bool> updateAvatar(String username, String avatarUrl) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/auth/user/avatar'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'avatar_url': avatarUrl,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          Logger.info('[UserService] Avatar updated for: $username');
          return true;
        }
      }

      Logger.error(
        '[UserService] Update avatar failed: ${response.statusCode}',
      );
      return false;
    } catch (e) {
      Logger.error('[UserService] Update avatar error: $e');
      return false;
    }
  }

  /// Refresh access token using refresh token
  static Future<bool> refreshAccessToken() async {
    try {
      if (_refreshToken == null || _refreshToken!.isEmpty) {
        Logger.warning('[UserService] No refresh token available');
        return false;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': _refreshToken}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _accessToken = data['access_token'];
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('access_token', _accessToken!);
          Logger.info('[UserService] Access token refreshed successfully');
          return true;
        }
      }

      if (response.statusCode == 401) {
        Logger.warning('[UserService] Refresh token expired, need to login again');
        await logout();
        return false;
      }

      Logger.error('[UserService] Token refresh failed: ${response.statusCode}');
      return false;
    } catch (e) {
      Logger.error('[UserService] Token refresh error: $e');
      return false;
    }
  }

  /// Get login history
  static Future<List<dynamic>?> getLoginHistory(String username) async {
    try {
      if (_accessToken == null) {
        Logger.warning('[UserService] No access token available');
        return null;
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/audit/login-history/$username'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          Logger.info('[UserService] Retrieved login history for: $username');
          return data['login_history'];
        }
      }

      Logger.error('[UserService] Get login history failed: ${response.statusCode}');
      return null;
    } catch (e) {
      Logger.error('[UserService] Get login history error: $e');
      return null;
    }
  }
}
