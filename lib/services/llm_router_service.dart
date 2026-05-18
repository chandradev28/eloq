import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/conversation/models/message.dart';
import '../features/topics/models/topic.dart';
import '../models/app_settings.dart';
import '../models/grammar_correction.dart';
import '../core/constants/prompts.dart';

class LlmResponse {
  const LlmResponse({
    required this.text,
    this.provider = 'demo',
    this.model = 'local',
    this.estimatedTokens = 0,
    this.corrections = const [],
  });

  final String text;
  final String provider;
  final String model;
  final int estimatedTokens;
  final List<GrammarCorrection> corrections;
}

class LlmRouterService {
  LlmRouterService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;
  final Map<String, DateTime> _cooldowns = {};

  Future<LlmResponse> sendMessage({
    required AppSettings settings,
    required Topic topic,
    required List<Message> history,
    required String userText,
    String extraInstructions = '',
    String learnerContext = '',
  }) async {
    if (!settings.hasAnyLlmKey) {
      return _demoResponse(topic, userText, settings.difficulty);
    }

    final systemPrompt = Prompts.conversationSystemPrompt(
      level: settings.difficulty,
      topic: topic,
      extraInstructions: extraInstructions,
      learnerContext: learnerContext,
    );
    final openAiMessages = [
      {'role': 'system', 'content': systemPrompt},
      ...history.reversed.take(6).toList().reversed.map((message) => {
            'role': message.isUser ? 'user' : 'assistant',
            'content': message.text,
          }),
      {'role': 'user', 'content': userText},
    ];

    final providers = [
      _ProviderConfig(
        id: 'groq',
        apiKey: settings.groqApiKey,
        baseUrl: 'https://api.groq.com/openai/v1',
        model: 'llama-3.3-70b-versatile',
      ),
      _ProviderConfig(
        id: 'cerebras',
        apiKey: settings.cerebrasApiKey,
        baseUrl: 'https://api.cerebras.ai/v1',
        model: 'qwen-3-235b-instruct',
      ),
      _ProviderConfig(
        id: 'sambanova',
        apiKey: settings.sambanovaApiKey,
        baseUrl: 'https://api.sambanova.ai/v1',
        model: 'Meta-Llama-3.3-70B-Instruct',
      ),
      _ProviderConfig(
        id: 'gemini',
        apiKey: settings.geminiApiKey,
        baseUrl: '',
        model: 'gemini-2.0-flash',
        isGemini: true,
      ),
      _ProviderConfig(
        id: 'openrouter',
        apiKey: settings.openRouterApiKey,
        baseUrl: 'https://openrouter.ai/api/v1',
        model: 'openrouter/free',
        headers: {'HTTP-Referer': 'https://eloq.app'},
      ),
    ];
    final orderedProviders = _orderProviders(
      providers,
      settings.preferredProvider,
    );

    for (final provider in orderedProviders) {
      if (!provider.isReady || _isCoolingDown(provider.id)) continue;
      try {
        final raw = provider.isGemini
            ? await _sendGemini(provider, systemPrompt, history, userText)
            : await _sendOpenAiCompatible(provider, openAiMessages);
        return _parseResponse(
          raw,
          provider.id,
          provider.model,
          _estimateTokens(openAiMessages, raw),
        );
      } on DioException catch (error) {
        final status = error.response?.statusCode ?? 0;
        if (status == 429 || status >= 500) {
          _cooldowns[provider.id] =
              DateTime.now().add(const Duration(seconds: 60));
          continue;
        }
      } catch (_) {}
    }

    final demo = _demoResponse(topic, userText, settings.difficulty);
    return LlmResponse(
      text:
          '${demo.text} I could not reach the configured AI providers, so this is a local practice reply.',
      provider: 'fallback',
      model: 'local',
      corrections: demo.corrections,
    );
  }

  Future<String?> validateProvider({
    required String provider,
    required String apiKey,
  }) async {
    if (apiKey.trim().isEmpty) return 'API key is empty.';
    try {
      final config = switch (provider) {
        'groq' => _ProviderConfig(
            id: 'groq',
            apiKey: apiKey,
            baseUrl: 'https://api.groq.com/openai/v1',
            model: 'llama-3.3-70b-versatile',
          ),
        'cerebras' => _ProviderConfig(
            id: 'cerebras',
            apiKey: apiKey,
            baseUrl: 'https://api.cerebras.ai/v1',
            model: 'qwen-3-235b-instruct',
          ),
        'sambanova' => _ProviderConfig(
            id: 'sambanova',
            apiKey: apiKey,
            baseUrl: 'https://api.sambanova.ai/v1',
            model: 'Meta-Llama-3.3-70B-Instruct',
          ),
        'gemini' => _ProviderConfig(
            id: 'gemini',
            apiKey: apiKey,
            baseUrl: '',
            model: 'gemini-2.0-flash',
            isGemini: true,
          ),
        'openrouter' => _ProviderConfig(
            id: 'openrouter',
            apiKey: apiKey,
            baseUrl: 'https://openrouter.ai/api/v1',
            model: 'openrouter/free',
            headers: {'HTTP-Referer': 'https://eloq.app'},
          ),
        _ => null,
      };
      if (config == null) return 'Unknown provider.';
      if (config.isGemini) {
        await _sendGemini(config, 'Reply with OK.', const [], 'OK');
      } else {
        await _sendOpenAiCompatible(config, const [
          {'role': 'user', 'content': 'Reply with OK.'},
        ]);
      }
      return null;
    } on DioException catch (error) {
      return error.response?.data?.toString() ?? error.message;
    } catch (error) {
      return error.toString();
    }
  }

  Future<String> _sendOpenAiCompatible(
    _ProviderConfig provider,
    List<Map<String, String>> messages,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '${provider.baseUrl}/chat/completions',
      options: Options(
        headers: {
          'Authorization': 'Bearer ${provider.apiKey}',
          'Content-Type': 'application/json',
          ...provider.headers,
        },
      ),
      data: {
        'model': provider.model,
        'messages': messages,
        'temperature': 0.7,
        'max_tokens': 300,
        'stream': false,
      },
    );

    return response.data?['choices']?[0]?['message']?['content']?.toString() ??
        'I am here. Could you say that again?';
  }

  Future<String> _sendGemini(
    _ProviderConfig provider,
    String systemPrompt,
    List<Message> history,
    String userText,
  ) async {
    final transcript = StringBuffer(systemPrompt);
    for (final message in history.reversed.take(6).toList().reversed) {
      transcript
          .writeln('${message.isUser ? 'Student' : 'Eloq'}: ${message.text}');
    }
    transcript.writeln('Student: $userText');

    final response = await _dio.post<Map<String, dynamic>>(
      'https://generativelanguage.googleapis.com/v1beta/models/${provider.model}:generateContent?key=${provider.apiKey}',
      data: {
        'contents': [
          {
            'parts': [
              {'text': transcript.toString()}
            ]
          }
        ],
        'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 300},
      },
    );

    return response.data?['candidates']?[0]?['content']?['parts']?[0]?['text']
            ?.toString() ??
        'I am here. Could you say that again?';
  }

  LlmResponse _parseResponse(
    String raw,
    String provider,
    String model,
    int estimatedTokens,
  ) {
    const start = '|||CORRECTIONS|||';
    const end = '|||END|||';
    final startIndex = raw.indexOf(start);
    final endIndex = raw.indexOf(end);
    if (startIndex == -1 || endIndex == -1 || endIndex <= startIndex) {
      return LlmResponse(
        text: raw.trim(),
        provider: provider,
        model: model,
        estimatedTokens: estimatedTokens,
      );
    }

    final spokenText = raw.substring(0, startIndex).trim();
    final jsonText = raw.substring(startIndex + start.length, endIndex).trim();
    final decoded = jsonDecode(jsonText);
    final corrections = decoded is List
        ? decoded
            .whereType<Map>()
            .map((item) =>
                GrammarCorrection.fromJson(Map<String, dynamic>.from(item)))
            .toList()
        : <GrammarCorrection>[];

    return LlmResponse(
      text: spokenText,
      provider: provider,
      model: model,
      estimatedTokens: estimatedTokens,
      corrections: corrections,
    );
  }

  bool _isCoolingDown(String id) {
    final until = _cooldowns[id];
    if (until == null) return false;
    if (DateTime.now().isAfter(until)) {
      _cooldowns.remove(id);
      return false;
    }
    return true;
  }

  LlmResponse _demoResponse(Topic topic, String userText, String level) {
    final hasWant = userText.toLowerCase().contains('i want');
    final response = switch (level) {
      'advanced' =>
        'Let us practice ${topic.name.toLowerCase()}. ${topic.prompt} Give me a detailed answer and I will respond naturally.',
      'intermediate' =>
        'Let us practice ${topic.name.toLowerCase()}. ${topic.prompt} Answer in a clear, natural way.',
      _ =>
        'Let us practice ${topic.name.toLowerCase()}. ${topic.prompt} Use simple English. I will help you.',
    };
    return LlmResponse(
      text: response,
      provider: 'demo',
      model: 'local',
      estimatedTokens: 0,
      corrections: hasWant
          ? const [
              GrammarCorrection(
                original: 'I want',
                corrected: "I'd like",
                explanation:
                    "I'd like sounds more polite in service situations.",
              ),
            ]
          : const [],
    );
  }

  int _estimateTokens(List<Map<String, String>> messages, String response) {
    final chars = response.length +
        messages.fold<int>(
            0, (sum, item) => sum + (item['content']?.length ?? 0));
    return (chars / 4).ceil().clamp(1, 100000);
  }

  List<_ProviderConfig> _orderProviders(
    List<_ProviderConfig> providers,
    String preferredProvider,
  ) {
    if (preferredProvider == 'auto') return providers;
    final preferred = providers.where((item) => item.id == preferredProvider);
    final remaining = providers.where((item) => item.id != preferredProvider);
    return [...preferred, ...remaining];
  }
}

class _ProviderConfig {
  const _ProviderConfig({
    required this.id,
    required this.apiKey,
    required this.baseUrl,
    required this.model,
    this.headers = const {},
    this.isGemini = false,
  });

  final String id;
  final String apiKey;
  final String baseUrl;
  final String model;
  final Map<String, String> headers;
  final bool isGemini;

  bool get isReady => apiKey.trim().isNotEmpty;
}

final llmRouterServiceProvider = Provider<LlmRouterService>((ref) {
  return LlmRouterService();
});
