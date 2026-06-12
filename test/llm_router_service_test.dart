import 'package:dio/dio.dart';
import 'package:eloq/core/constants/topics.dart';
import 'package:eloq/models/app_settings.dart';
import 'package:eloq/services/llm_router_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LlmRouterService Groq routing', () {
    test('Fast mode uses Llama 3.1 8B Instant', () async {
      final harness = _GroqHarness(
        availableModels: const ['llama-3.1-8b-instant'],
      );

      final response = await harness.service.sendMessage(
        settings: const AppSettings(
          groqApiKey: 'gsk_test',
          groqChatMode: 'fast',
        ),
        topic: Topics.byId('free_talk'),
        history: const [],
        userText: 'Hello',
      );

      expect(harness.requestedModel, 'llama-3.1-8b-instant');
      expect(response.model, 'llama-3.1-8b-instant');
      expect(response.provider, 'groq');
    });

    test('Smart mode uses GPT-OSS 120B', () async {
      final harness = _GroqHarness(
        availableModels: const [
          'openai/gpt-oss-120b',
          'llama-3.1-8b-instant',
        ],
      );

      final response = await harness.service.sendMessage(
        settings: const AppSettings(
          groqApiKey: 'gsk_test',
          groqChatMode: 'smart',
        ),
        topic: Topics.byId('free_talk'),
        history: const [],
        userText: 'Help me practice',
      );

      expect(harness.requestedModel, 'openai/gpt-oss-120b');
      expect(response.model, 'openai/gpt-oss-120b');
    });

    test('Smart mode selects an allowed Groq fallback without a failed call',
        () async {
      final harness = _GroqHarness(
        availableModels: const ['llama-3.1-8b-instant'],
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

      expect(harness.chatRequests, 1);
      expect(harness.requestedModel, 'llama-3.1-8b-instant');
      expect(response.model, 'llama-3.1-8b-instant');
    });
  });
}

class _GroqHarness {
  _GroqHarness({required List<String> availableModels}) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path.endsWith('/models')) {
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'data': [
                    for (final model in availableModels) {'id': model},
                  ],
                },
              ),
            );
            return;
          }

          chatRequests += 1;
          requestedModel =
              (options.data as Map<String, dynamic>)['model']?.toString();
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'choices': [
                  {
                    'message': {'content': 'Hello. How are you today?'},
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

  final Dio dio = Dio();
  late final LlmRouterService service;
  String? requestedModel;
  int chatRequests = 0;
}
