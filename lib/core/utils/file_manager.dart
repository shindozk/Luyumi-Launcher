import 'dart:io';
import 'package:http/http.dart' as http;
import 'logger.dart';

class FileManager {
  static Future<void> downloadFile(String url, String destination, {Function(String, double)? progress}) async {
    final request = http.Request('GET', Uri.parse(url));
    final response = await http.Client().send(request);
    
    if (response.statusCode != 200) {
      throw Exception('Failed to download file: ${response.statusCode}');
    }

    final file = File(destination);
    await file.parent.create(recursive: true);
    
    final contentLength = response.contentLength ?? 0;
    final fileSink = file.openWrite();
    int received = 0;
    
    await response.stream.listen(
      (chunk) {
        fileSink.add(chunk);
        received += chunk.length;
        if (contentLength > 0 && progress != null) {
          progress("Downloading...", received / contentLength);
        }
      },
      onDone: () async {
        await fileSink.close();
      },
      onError: (e) {
        fileSink.close();
        throw e;
      },
      cancelOnError: true,
    ).asFuture();
  }

  static Future<bool> openFolder(String path) async {
    if (!await Directory(path).exists()) return false;
    
    try {
      if (Platform.isWindows) {
        await Process.run('explorer.exe', [path]);
        return true;
      } else if (Platform.isMacOS) {
        await Process.run('open', [path]);
        return true;
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [path]);
        return true;
      }
    } catch (e) {
      Logger.error("Error opening folder: $e");
    }
    return false;
  }

  static Future<String> readFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      return await file.readAsString();
    }
    return '';
  }
}
