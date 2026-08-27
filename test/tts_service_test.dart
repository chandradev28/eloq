import 'package:eloq/services/tts_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';

void main() {
  group('TtsService.normalizeSpeed', () {
    final androidRange = SpeechRateValidRange(
      0.0,
      0.5,
      1.5,
      TextToSpeechPlatform.android,
    );

    test('maps 1.0x to platform normal speed', () {
      expect(
        TtsService.normalizeSpeed(speed: 1.0, range: androidRange),
        0.5,
      );
    });

    test('maps lower user speeds below platform normal', () {
      expect(
        TtsService.normalizeSpeed(speed: 0.5, range: androidRange),
        0.0,
      );
      expect(
        TtsService.normalizeSpeed(speed: 0.75, range: androidRange),
        0.25,
      );
    });

    test('maps higher user speeds above platform normal', () {
      expect(
        TtsService.normalizeSpeed(speed: 1.5, range: androidRange),
        1.0,
      );
      expect(
        TtsService.normalizeSpeed(speed: 2.0, range: androidRange),
        1.5,
      );
    });

    test('falls back to the raw user speed when no range is available', () {
      expect(
        TtsService.normalizeSpeed(speed: 1.3, range: null),
        1.3,
      );
    });
  });

  group('TtsService.playbackTimeoutSeconds', () {
    test('allows slower voices enough time to finish', () {
      final text = List.filled(120, 'word').join(' ');
      expect(
        TtsService.playbackTimeoutSeconds(text, speed: 0.5),
        greaterThan(
          TtsService.playbackTimeoutSeconds(text, speed: 1.5),
        ),
      );
    });

    test('keeps a safe minimum for short replies', () {
      expect(
        TtsService.playbackTimeoutSeconds('Hello.', speed: 2.0),
        12,
      );
    });
  });
}
