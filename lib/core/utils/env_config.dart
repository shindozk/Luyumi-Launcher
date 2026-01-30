import 'package:crypto/crypto.dart';

/// Environment configuration with encryption support
class EnvConfig {
  static const String _encryptionKey = 'luyumi_launcher_secure_key_2026';
  
  /// Simple XOR encryption for environment variables
  /// Note: This is NOT cryptographically secure but obfuscates the data
  /// For production, use a proper encryption library
  static String _encryptDecrypt(String text) {
    final key = _encryptionKey.codeUnits;
    final bytes = text.codeUnits;
    
    List<int> encrypted = [];
    for (int i = 0; i < bytes.length; i++) {
      encrypted.add(bytes[i] ^ key[i % key.length]);
    }
    
    return encrypted.map((e) => e.toRadixString(16).padLeft(2, '0')).join('');
  }
  
  static String _decryptText(String encrypted) {
    final key = _encryptionKey.codeUnits;
    final bytes = <int>[];
    
    for (int i = 0; i < encrypted.length; i += 2) {
      bytes.add(int.parse(encrypted.substring(i, i + 2), radix: 16));
    }
    
    List<int> decrypted = [];
    for (int i = 0; i < bytes.length; i++) {
      decrypted.add(bytes[i] ^ key[i % key.length]);
    }
    
    return String.fromCharCodes(decrypted);
  }
  
  /// Load environment variables from encrypted asset
  static Future<Map<String, String>> loadEnv() async {
    try {
      // In production, load from encrypted file
      // For now, return empty map - environment will come from backend
      return {};
    } catch (e) {
      // Fallback: return empty map
      return {};
    }
  }
  
  /// Obfuscate sensitive data for logging
  static String obscure(String value) {
    if (value.isEmpty) return '';
    if (value.length <= 4) return '****';
    final firstTwo = value.substring(0, 2);
    final lastTwo = value.substring(value.length - 2);
    return '$firstTwo${'*' * (value.length - 4)}$lastTwo';
  }
}
