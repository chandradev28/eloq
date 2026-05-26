import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class GeminiLiveUsage {
  const GeminiLiveUsage({
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.totalTokens = 0,
  });

  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
}

sealed class GeminiLiveEvent {
  const GeminiLiveEvent();
}

class GeminiLiveConnected extends GeminiLiveEvent {
  const GeminiLiveConnected();
}

class GeminiLiveInterrupted extends GeminiLiveEvent {
  const GeminiLiveInterrupted();
}

class GeminiLiveTurnComplete extends GeminiLiveEvent {
  const GeminiLiveTurnComplete();
}

class GeminiLiveInputTranscript extends GeminiLiveEvent {
  const GeminiLiveInputTranscript(this.text);

  final String text;
}

class GeminiLiveOutputTranscript extends GeminiLiveEvent {
  const GeminiLiveOutputTranscript(this.text);

  final String text;
}

class GeminiLiveUsageEvent extends GeminiLiveEvent {
  const GeminiLiveUsageEvent(this.usage);

  final GeminiLiveUsage usage;
}

class GeminiLiveError extends GeminiLiveEvent {
  const GeminiLiveError(this.message);

  final String message;
}

class GeminiLiveService {
  static const _endpoint =
      'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent';
  static const defaultModel =
      'models/gemini-2.5-flash-native-audio-preview-12-2025';

  final _events = StreamController<GeminiLiveEvent>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  bool _isConnected = false;

  Stream<GeminiLiveEvent> get events => _events.stream;
  bool get isConnected => _isConnected;

  Future<void> connect({
    required String apiKey,
    required String systemInstruction,
    String model = defaultModel,
  }) async {
    await disconnect();

    final uri = Uri.parse(_endpoint).replace(queryParameters: {'key': apiKey});
    final channel = WebSocketChannel.connect(uri);
    _channel = channel;
    _subscription = channel.stream.listen(
      _handleMessage,
      onError: (Object error, StackTrace stackTrace) {
        _isConnected = false;
        _events.add(GeminiLiveError(error.toString()));
      },
      onDone: () {
        _isConnected = false;
      },
    );

    _send({
      'setup': {
        'model': model,
        'generationConfig': {
          'responseModalities': ['TEXT'],
          'temperature': 0.7,
          'maxOutputTokens': 180,
        },
        'systemInstruction': {
          'parts': [
            {'text': systemInstruction}
          ],
        },
        'inputAudioTranscription': {},
        'outputAudioTranscription': {},
        'realtimeInputConfig': {
          'activityHandling': 'START_OF_ACTIVITY_INTERRUPTS',
          'automaticActivityDetection': {
            'disabled': false,
            'prefixPaddingMs': 120,
            'silenceDurationMs': 700,
          },
        },
      },
    });
  }

  Future<void> sendAudioChunk(Uint8List bytes) async {
    if (!_isConnected || bytes.isEmpty) return;
    _send({
      'realtimeInput': {
        'audio': {
          'data': base64Encode(bytes),
          'mimeType': 'audio/pcm;rate=16000',
        },
      },
    });
  }

  Future<void> signalAudioStreamEnd() async {
    if (!_isConnected) return;
    _send({
      'realtimeInput': {'audioStreamEnd': true},
    });
  }

  Future<void> disconnect() async {
    _isConnected = false;
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  void _handleMessage(dynamic raw) {
    try {
      final decoded = jsonDecode(raw as String) as Map<String, dynamic>;

      if (decoded.containsKey('setupComplete')) {
        _isConnected = true;
        _events.add(const GeminiLiveConnected());
      }

      final usage = decoded['usageMetadata'];
      if (usage is Map<String, dynamic>) {
        _events.add(
          GeminiLiveUsageEvent(
            GeminiLiveUsage(
              promptTokens: _readInt(
                usage['promptTokenCount'] ?? usage['prompt_tokens'],
              ),
              completionTokens: _readInt(
                usage['responseTokenCount'] ??
                    usage['candidatesTokenCount'] ??
                    usage['completion_tokens'],
              ),
              totalTokens: _readInt(
                usage['totalTokenCount'] ?? usage['total_tokens'],
              ),
            ),
          ),
        );
      }

      final serverContent = decoded['serverContent'];
      if (serverContent is! Map<String, dynamic>) return;

      final input = serverContent['inputTranscription'];
      final inputText = _readTranscript(input);
      if (inputText.isNotEmpty) {
        _events.add(GeminiLiveInputTranscript(inputText));
      }

      final output = serverContent['outputTranscription'];
      final outputText = _readTranscript(output);
      if (outputText.isNotEmpty) {
        _events.add(GeminiLiveOutputTranscript(outputText));
      }

      final modelTurn = serverContent['modelTurn'];
      if (modelTurn is Map<String, dynamic>) {
        final modelText = _readModelText(modelTurn);
        if (modelText.isNotEmpty) {
          _events.add(GeminiLiveOutputTranscript(modelText));
        }
      }

      if (serverContent['interrupted'] == true) {
        _events.add(const GeminiLiveInterrupted());
      }
      if (serverContent['turnComplete'] == true ||
          serverContent['generationComplete'] == true) {
        _events.add(const GeminiLiveTurnComplete());
      }
    } catch (error) {
      _events.add(GeminiLiveError(error.toString()));
    }
  }

  String _readTranscript(Object? data) {
    if (data is Map<String, dynamic>) {
      final text = data['text'];
      if (text is String) return text.trim();
    }
    return '';
  }

  String _readModelText(Map<String, dynamic> modelTurn) {
    final parts = modelTurn['parts'];
    if (parts is! List) return '';
    final buffer = StringBuffer();
    for (final part in parts) {
      if (part is Map<String, dynamic>) {
        final text = part['text'];
        if (text is String && text.trim().isNotEmpty) {
          buffer.write(text);
        }
      }
    }
    return buffer.toString().trim();
  }

  int _readInt(Object? value) {
    return switch (value) {
      num number => number.toInt(),
      _ => 0,
    };
  }

  void _send(Map<String, dynamic> payload) {
    _channel?.sink.add(jsonEncode(payload));
  }
}

final geminiLiveServiceProvider = Provider<GeminiLiveService>((ref) {
  final service = GeminiLiveService();
  ref.onDispose(service.disconnect);
  return service;
});
