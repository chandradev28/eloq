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
    await _ignoreTimeout(_tts.stop());
    final completer = Completer<void>();
    _speakCompleter = completer;
    await _tts.awaitSpeakCompletion(true).timeout(const Duration(seconds: 2));
    await _tts
        .setSpeechRate(
          normalizeSpeed(
            speed: speed,
            range: await _loadSpeechRateRange(),
          ),
        )
        .timeout(const Duration(seconds: 2));
    final result = await _tts.speak(text).timeout(const Duration(seconds: 3));
    if (result == 0 || result == false) {
      _finishSpeaking();
      throw StateError('The device voice engine could not start playback.');
    }
    final maxPlaybackSeconds = (text.length / 8).ceil().clamp(8, 90);
    await completer.future.timeout(
      Duration(seconds: maxPlaybackSeconds),
      onTimeout: _finishSpeaking,
    );
  }

  Future<void> stop() async {
    _finishSpeaking();
    await _ignoreTimeout(_tts.stop());
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
        final range = await _tts.getSpeechRateValidRange
            .timeout(const Duration(seconds: 2));
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

  Future<void> _ignoreTimeout(Future<dynamic> operation) async {
    try {
      await operation.timeout(const Duration(seconds: 2));
    } catch (_) {
      // Playback setup must never block the conversation loop indefinitely.
    }
  }
}

final ttsServiceProvider = Provider<TtsService>((ref) => TtsService());
