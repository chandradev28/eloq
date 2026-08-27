import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
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

class GeminiLiveAudioChunk extends GeminiLiveEvent {
  const GeminiLiveAudioChunk(this.bytes);

  final Uint8List bytes;
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
  static const defaultModel = 'models/gemini-3.1-flash-live-preview';

  final _events = StreamController<GeminiLiveEvent>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _setupTimer;
  bool _isConnected = false;
  int _connectionGeneration = 0;

  Stream<GeminiLiveEvent> get events => _events.stream;
  bool get isConnected => _isConnected;

  @visibleForTesting
  void handleMessageForTest(Object raw) {
    _handleMessage(raw, _connectionGeneration);
  }

  Future<void> connect({
    required String apiKey,
    required String systemInstruction,
    String model = defaultModel,
    String voiceName = 'Kore',
  }) async {
    await disconnect();
    final generation = ++_connectionGeneration;

    final uri = Uri.parse(_endpoint).replace(queryParameters: {'key': apiKey});
    final channel = WebSocketChannel.connect(uri);
    _channel = channel;
    await channel.ready.timeout(const Duration(seconds: 8));
    _subscription = channel.stream.listen(
      (raw) => _handleMessage(raw, generation),
      onError: (Object error, StackTrace stackTrace) {
        if (generation != _connectionGeneration) return;
        _isConnected = false;
        _setupTimer?.cancel();
        _events.add(GeminiLiveError(error.toString()));
      },
      onDone: () {
        if (generation != _connectionGeneration) return;
        final wasConnected = _isConnected;
        _isConnected = false;
        _setupTimer?.cancel();
        if (wasConnected) {
          _events
              .add(const GeminiLiveError('The Live Voice connection closed.'));
        }
      },
    );

    _send({
      'setup': {
        'model': model,
        'generationConfig': {
          'responseModalities': ['AUDIO'],
          'temperature': 0.7,
          'maxOutputTokens': 180,
          'thinkingConfig': {'thinkingLevel': 'minimal'},
          'speechConfig': {
            'voiceConfig': {
              'prebuiltVoiceConfig': {'voiceName': voiceName}
            }
          },
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
    _setupTimer = Timer(const Duration(seconds: 10), () {
      if (generation == _connectionGeneration && !_isConnected) {
        _events.add(
          const GeminiLiveError('Live Voice could not finish connecting.'),
        );
        unawaited(disconnect());
      }
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
    _connectionGeneration++;
    _isConnected = false;
    _setupTimer?.cancel();
    _setupTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  void _handleMessage(dynamic raw, int generation) {
    if (generation != _connectionGeneration) return;
    try {
      final encoded = switch (raw) {
        String text => text,
        List<int> bytes => utf8.decode(bytes),
        _ => throw const FormatException('Unsupported Live Voice message.'),
      };
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;

      if (decoded.containsKey('setupComplete')) {
        _isConnected = true;
        _setupTimer?.cancel();
        _setupTimer = null;
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
        _emitModelParts(modelTurn);
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

  void _emitModelParts(Map<String, dynamic> modelTurn) {
    final parts = modelTurn['parts'];
    if (parts is! List) return;
    for (final part in parts) {
      if (part is Map<String, dynamic>) {
        final text = part['text'];
        if (text is String && text.trim().isNotEmpty) {
          _events.add(GeminiLiveOutputTranscript(text.trim()));
        }
        final inlineData = part['inlineData'];
        if (inlineData is Map<String, dynamic>) {
          final mimeType = inlineData['mimeType']?.toString() ?? '';
          final data = inlineData['data'];
          if (mimeType.startsWith('audio/') && data is String) {
            _events.add(GeminiLiveAudioChunk(base64Decode(data)));
          }
        }
      }
    }
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
