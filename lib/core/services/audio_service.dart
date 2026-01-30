import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  
  factory AudioService() {
    return _instance;
  }

  AudioService._internal();

  final AudioPlayer _introPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();

  // Paths - keys as defined in pubspec.yaml
  static const String _introSoundKey = 'lib/assets/sounds/audio-intro.mp3';
  static const String _clickSoundKey = 'lib/assets/sounds/click-action.mp3';

  Future<void> init() async {
    // Optional: Preload or configure players
    await _sfxPlayer.setPlayerMode(PlayerMode.lowLatency);
  }

  Future<void> playIntro() async {
    try {
      final bytes = await rootBundle.load(_introSoundKey);
      await _introPlayer.play(BytesSource(bytes.buffer.asUint8List()));
    } catch (e) {
      debugPrint('Error playing intro audio: $e');
    }
  }

  Future<void> playClick() async {
    try {
      // Stop previous click to allow rapid firing or overlap? 
      // Overlap is better for rapid clicks but requires multiple players or low latency mode.
      // For simple UI, stopping previous is often fine or just fire and forget.
      // If we stop, we cut off the sound. If we don't, we might miss if it's already playing.
      // With low latency mode, we can just play.
      if (_sfxPlayer.state == PlayerState.playing) {
        await _sfxPlayer.stop();
      }
      
      // Load bytes every time might be slow? 
      // Better to cache the bytes.
      // But for now let's rely on OS caching or load once.
      // Let's load via rootBundle.
      
      final bytes = await rootBundle.load(_clickSoundKey);
      await _sfxPlayer.play(BytesSource(bytes.buffer.asUint8List()), volume: 0.5);
    } catch (e) {
      debugPrint('Error playing click audio: $e');
    }
  }
}
