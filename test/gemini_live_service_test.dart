import 'dart:convert';

import 'package:eloq/services/gemini_live_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('emits transcript, native audio, usage, and turn completion', () async {
    final service = GeminiLiveService();
    final events = <GeminiLiveEvent>[];
    final subscription = service.events.listen(events.add);

    service.handleMessageForTest(
      jsonEncode({
        'usageMetadata': {
          'promptTokenCount': 12,
          'responseTokenCount': 8,
          'totalTokenCount': 20,
        },
        'serverContent': {
          'inputTranscription': {'text': 'Hello'},
          'outputTranscription': {'text': 'Hi there'},
          'modelTurn': {
            'parts': [
              {
                'inlineData': {
                  'mimeType': 'audio/pcm;rate=24000',
                  'data': base64Encode([1, 2, 3, 4]),
                },
              },
            ],
          },
          'turnComplete': true,
        },
      }),
    );
    await Future<void>.delayed(Duration.zero);

    expect(
      events.whereType<GeminiLiveInputTranscript>().single.text,
      'Hello',
    );
    expect(
      events.whereType<GeminiLiveOutputTranscript>().single.text,
      'Hi there',
    );
    expect(
      events.whereType<GeminiLiveAudioChunk>().single.bytes,
      [1, 2, 3, 4],
    );
    expect(events.whereType<GeminiLiveTurnComplete>(), hasLength(1));
    expect(
        events.whereType<GeminiLiveUsageEvent>().single.usage.totalTokens, 20);

    await subscription.cancel();
    await service.disconnect();
  });
}
