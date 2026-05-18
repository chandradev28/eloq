import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  TtsService({FlutterTts? tts}) : _tts = tts ?? FlutterTts() {
    _tts.setCompletionHandler(_finishSpeaking);
    _tts.setCancelHandler(_finishSpeaking);
    _tts.setErrorHandler((_) => _finishSpeaking());
  }

  final FlutterTts _tts;
  Completer<void>? _speakCompleter;

  Future<void> speak(String text, {double speed = 1.0}) async {
    _speakCompleter?.complete();
    _speakCompleter = Completer<void>();
    await _tts.awaitSpeakCompletion(true);
    await _tts.setSpeechRate(speed.clamp(0.5, 2.0));
    await _tts.speak(text);
    await _speakCompleter?.future;
  }

  Future<void> stop() async {
    _finishSpeaking();
    await _tts.stop();
  }

  void _finishSpeaking() {
    final completer = _speakCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }
}

final ttsServiceProvider = Provider<TtsService>((ref) => TtsService());
