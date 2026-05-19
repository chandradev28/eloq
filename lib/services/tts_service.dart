import 'dart:async';

import 'package:flutter/foundation.dart';
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
  SpeechRateValidRange? _speechRateRange;
  Future<SpeechRateValidRange?>? _speechRateRangeFuture;

  Future<void> speak(String text, {double speed = 1.0}) async {
    _finishSpeaking();
    _speakCompleter = null;
    await _tts.stop();
    final completer = Completer<void>();
    _speakCompleter = completer;
    await _tts.awaitSpeakCompletion(true);
    await _tts.setSpeechRate(
      normalizeSpeed(
        speed: speed,
        range: await _loadSpeechRateRange(),
      ),
    );
    await _tts.speak(text);
    await completer.future;
  }

  Future<void> stop() async {
    _finishSpeaking();
    await _tts.stop();
  }

  void _finishSpeaking() {
    final completer = _speakCompleter;
    _speakCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  Future<SpeechRateValidRange?> _loadSpeechRateRange() async {
    if (_speechRateRange != null) return _speechRateRange;
    if (_speechRateRangeFuture != null) return _speechRateRangeFuture;

    _speechRateRangeFuture = () async {
      try {
        final range = await _tts.getSpeechRateValidRange;
        _speechRateRange = range;
        return range;
      } catch (_) {
        return null;
      } finally {
        _speechRateRangeFuture = null;
      }
    }();

    return _speechRateRangeFuture;
  }

  @visibleForTesting
  static double normalizeSpeed({
    required double speed,
    required SpeechRateValidRange? range,
  }) {
    final userSpeed = speed.clamp(0.5, 2.0);
    if (range == null) {
      return userSpeed;
    }

    if (userSpeed <= 1.0) {
      final t = (userSpeed - 0.5) / 0.5;
      return _lerp(range.min, range.normal, t);
    }

    final t = (userSpeed - 1.0) / 1.0;
    return _lerp(range.normal, range.max, t);
  }

  static double _lerp(double start, double end, double t) {
    final amount = t.clamp(0.0, 1.0);
    return start + ((end - start) * amount);
  }
}

final ttsServiceProvider = Provider<TtsService>((ref) => TtsService());
