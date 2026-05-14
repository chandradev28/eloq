import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  TtsService({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  Future<void> speak(String text, {double speed = 1.0}) async {
    await _tts.setSpeechRate(speed.clamp(0.5, 2.0));
    await _tts.speak(text);
  }

  Future<void> stop() => _tts.stop();
}

final ttsServiceProvider = Provider<TtsService>((ref) => TtsService());
