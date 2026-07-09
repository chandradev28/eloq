import 'package:dio/dio.dart';
import 'package:eloq/core/constants/topics.dart';
import 'package:eloq/models/app_settings.dart';
import 'package:eloq/services/llm_router_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LlmRouterService Groq routing', () {
    test('Fast mode uses Llama 4 Scout', () async {
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
        'meta-llama/llama-4-scout-17b-16e-instruct',
      );
      expect(harness.lastPayload?['max_completion_tokens'], 300);
      expect(harness.lastPayload?.containsKey('max_tokens'), isFalse);
      expect(harness.lastPayload?.containsKey('reasoning_effort'), isFalse);
      expect(harness.lastPayload?.containsKey('include_reasoning'), isFalse);
      expect(response.model, 'meta-llama/llama-4-scout-17b-16e-instruct');
      expect(response.provider, 'groq');
    });

    test('Fast mode falls back to Llama 3.1 8B when Scout is rejected',
        () async {
      final harness = _GroqHarness(
        statusByModel: const {
          'meta-llama/llama-4-scout-17b-16e-instruct': 404,
        },
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

      expect(harness.requestedModels, [
        'meta-llama/llama-4-scout-17b-16e-instruct',
        'llama-3.1-8b-instant',
      ]);
      expect(response.model, 'llama-3.1-8b-instant');
    });

    test('Smart mode uses Llama 4 Maverick', () async {
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
        'meta-llama/llama-4-maverick-17b-128e-instruct',
      );
      expect(response.model, 'meta-llama/llama-4-maverick-17b-128e-instruct');
    });

    test('Smart mode selects an allowed Groq fallback after a rejected model',
        () async {
      final harness = _GroqHarness(
        statusByModel: const {
          'meta-llama/llama-4-maverick-17b-128e-instruct': 404,
          'meta-llama/llama-4-scout-17b-16e-instruct': 404,
          'llama-3.3-70b-versatile': 404,
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

      expect(harness.chatRequests, 4);
      expect(harness.requestedModel, 'llama-3.1-8b-instant');
      expect(response.model, 'llama-3.1-8b-instant');
    });
  });
}

class _GroqHarness {
  _GroqHarness({this.statusByModel = const {}}) {
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

  final Map<String, int> statusByModel;
  final Dio dio = Dio();
  late final LlmRouterService service;
  String? requestedModel;
  Map<String, dynamic>? lastPayload;
  final requestedModels = <String>[];
  int chatRequests = 0;
}
