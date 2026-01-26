import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import '../config_manager.dart';

class PlayerService {
  static Future<String> getOrCreatePlayerId() async {
    final appDir = await ConfigManager().getAppDir();
    await Directory(appDir).create(recursive: true);
    final playerFile = File(path.join(appDir, 'player_id.json'));
    
    if (await playerFile.exists()) {
      try {
        final content = await playerFile.readAsString();
        final data = jsonDecode(content);
        final playerId = data['playerId'];
        if (playerId != null && playerId is String) {
          return playerId;
        }
      } catch (_) {}
    }

    final newId = const Uuid().v4();
    final data = {
      'playerId': newId,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    
    // Pretty print JSON
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
    await playerFile.writeAsString(jsonStr);
    
    return newId;
  }
}
