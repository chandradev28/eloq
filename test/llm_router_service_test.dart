import 'package:dio/dio.dart';
import 'package:eloq/core/constants/topics.dart';
import 'package:eloq/models/app_settings.dart';
import 'package:eloq/services/llm_router_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LlmRouterService Groq routing', () {
    test('Fast mode uses current Groq GPT-OSS 20B model', () async {
      final harness = _GroqHarness();

      final response = await harness.service.sendMessage(
        settings: const AppSettings(
          groqApiKey: 'gsk_test',
          groqChatMode: 'fast',
        ),
        topic: Topics.byId('free_talk'),
        history: const [],
        userText: 'Hello',
      );

      expect(
        harness.requestedModel,
        'openai/gpt-oss-20b',
      );
      expect(harness.lastPayload?['max_completion_tokens'], 300);
      expect(harness.lastPayload?.containsKey('max_tokens'), isFalse);
      expect(harness.lastPayload?['reasoning_effort'], 'low');
      expect(harness.lastPayload?['include_reasoning'], isFalse);
      expect(response.model, 'openai/gpt-oss-20b');
      expect(response.provider, 'groq');
    });

    test('Fast mode never requests retired Groq models', () async {
      final harness = _GroqHarness();

      final response = await harness.service.sendMessage(
        settings: const AppSettings(
          groqApiKey: 'gsk_test',
          groqChatMode: 'fast',
        ),
        topic: Topics.byId('free_talk'),
        history: const [],
        userText: 'Hello',
      );

      expect(harness.requestedModels, ['openai/gpt-oss-20b']);
      expect(response.model, 'openai/gpt-oss-20b');
    });

    test('Smart mode uses current Groq GPT-OSS 120B model', () async {
      final harness = _GroqHarness();

      final response = await harness.service.sendMessage(
        settings: const AppSettings(
          groqApiKey: 'gsk_test',
          groqChatMode: 'smart',
        ),
        topic: Topics.byId('free_talk'),
        history: const [],
        userText: 'Help me practice',
      );

      expect(
        harness.requestedModel,
        'openai/gpt-oss-120b',
      );
      expect(harness.lastPayload?['reasoning_effort'], 'medium');
      expect(response.model, 'openai/gpt-oss-120b');
    });

    test('Smart mode selects an allowed Groq fallback after a rejected model',
        () async {
      final harness = _GroqHarness(
        statusByModel: const {
          'openai/gpt-oss-120b': 404,
        },
      );

      final response = await harness.service.sendMessage(
        settings: const AppSettings(
          groqApiKey: 'gsk_test',
          groqChatMode: 'smart',
        ),
        topic: Topics.byId('free_talk'),
        history: const [],
        userText: 'Hello',
      );

      expect(harness.chatRequests, 2);
      expect(harness.requestedModel, 'openai/gpt-oss-20b');
      expect(response.model, 'openai/gpt-oss-20b');
    });

    test('Malformed correction JSON does not discard a valid reply', () async {
      final harness = _GroqHarness(
        responseText: 'Good answer. |||CORRECTIONS||| not-json |||END|||',
      );

      final response = await harness.service.sendMessage(
        settings: const AppSettings(groqApiKey: 'gsk_test'),
        topic: Topics.byId('free_talk'),
        history: const [],
        userText: 'Hello',
      );

      expect(response.text, 'Good answer.');
      expect(response.provider, 'groq');
      expect(response.corrections, isEmpty);
    });
  });
}

class _GroqHarness {
  _GroqHarness({
    this.statusByModel = const {},
    this.responseText = 'Hello. How are you today?',
  }) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          chatRequests += 1;
          lastPayload = Map<String, dynamic>.from(
            options.data as Map<String, dynamic>,
          );
          requestedModel = lastPayload?['model']?.toString();
          if (requestedModel != null) {
            requestedModels.add(requestedModel!);
          }
          final status = statusByModel[requestedModel];
          if (status != null) {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: status,
                  data: {
                    'error': {'message': 'model unavailable'},
                  },
                ),
                type: DioExceptionType.badResponse,
              ),
            );
            return;
          }
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'choices': [
                  {
                    'message': {'content': responseText},
                  },
                ],
                'usage': {
                  'prompt_tokens': 20,
                  'completion_tokens': 8,
                  'total_tokens': 28,
                },
              },
            ),
          );
        },
      ),
    );
    service = LlmRouterService(dio: dio);
  }

  final Map<String, int> statusByModel;
  final String responseText;
  final Dio dio = Dio();
  late final LlmRouterService service;
  String? requestedModel;
  Map<String, dynamic>? lastPayload;
  final requestedModels = <String>[];
  int chatRequests = 0;
}
