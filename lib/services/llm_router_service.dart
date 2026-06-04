import 'dart:async';
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
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.totalTokens = 0,
    this.isTokenUsageEstimated = true,
    this.corrections = const [],
  });

  final String text;
  final String provider;
  final String model;
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final bool isTokenUsageEstimated;
  final List<GrammarCorrection> corrections;
}

class _ProviderResult {
  const _ProviderResult({
    required this.text,
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.totalTokens = 0,
  });

  final String text;
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
}

class LlmRouterService {
  LlmRouterService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: _connectTimeout,
              sendTimeout: _sendTimeout,
              receiveTimeout: _defaultRequestTimeout,
            ));

  final Dio _dio;
  final Map<String, DateTime> _cooldowns = {};
  static const _connectTimeout = Duration(seconds: 8);
  static const _sendTimeout = Duration(seconds: 10);
  static const _defaultRequestTimeout = Duration(seconds: 18);

  Future<LlmResponse> sendMessage({
    required AppSettings settings,
    required Topic topic,
    required List<Message> history,
    required String userText,
    String extraInstructions = '',
    String learnerContext = '',
    int maxOutputTokens = 300,
    int maxHistoryMessages = 6,
    List<String>? allowedProviderIds,
    bool preferLowLatency = false,
    Duration requestTimeout = _defaultRequestTimeout,
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
      ...history.reversed
          .take(maxHistoryMessages)
          .toList()
          .reversed
          .map((message) => {
                'role': message.isUser ? 'user' : 'assistant',
                'content': message.text,
              }),
      {'role': 'user', 'content': userText},
    ];

    final providers = [
      ..._groqProviders(settings, preferLowLatency: preferLowLatency),
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
      _ProviderConfig(
        id: 'deepseek',
        apiKey: settings.deepSeekApiKey,
        baseUrl: 'https://api.deepseek.com',
        model: settings.deepSeekChatModel,
      ),
    ];
    final allowed = allowedProviderIds?.toSet();
    final readyProviders = allowed == null
        ? providers
        : providers.where((provider) => allowed.contains(provider.id)).toList();
    final orderedProviders = _orderProviders(
      readyProviders,
      settings.preferredProvider,
    );
    final failures = <String>[];

    for (final provider in orderedProviders) {
      if (!provider.isReady || _isCoolingDown(provider.cooldownKey)) continue;
      try {
        final result = provider.isGemini
            ? await _sendGemini(
                provider,
                systemPrompt,
                history,
                userText,
                maxOutputTokens: maxOutputTokens,
                maxHistoryMessages: maxHistoryMessages,
                requestTimeout: requestTimeout,
              )
            : await _sendOpenAiCompatible(
                provider,
                openAiMessages,
                maxOutputTokens: maxOutputTokens,
                requestTimeout: requestTimeout,
              );
        final exactTotalTokens = result.totalTokens;
        return _parseResponse(
          result.text,
          provider.id,
          provider.model,
          promptTokens: result.promptTokens,
          completionTokens: result.completionTokens,
          totalTokens: exactTotalTokens > 0
              ? exactTotalTokens
              : _estimateTokens(openAiMessages, result.text),
          isTokenUsageEstimated: exactTotalTokens <= 0,
        );
      } on DioException catch (error) {
        failures.add(_failureText(provider, error));
        if (_shouldCooldown(error)) {
          _cooldowns[provider.cooldownKey] =
              DateTime.now().add(const Duration(seconds: 60));
        }
        continue;
      } on TimeoutException {
        failures.add('${provider.label} timed out.');
        _cooldowns[provider.cooldownKey] =
            DateTime.now().add(const Duration(seconds: 45));
        continue;
      } catch (error) {
        failures.add('${provider.label}: $error');
        continue;
      }
    }

    final demo = _demoResponse(topic, userText, settings.difficulty);
    final reason = failures.isEmpty ? '' : ' (${failures.first})';
    return LlmResponse(
      text:
          '${demo.text} I could not reach the configured AI providers quickly$reason, so this is a local practice reply.',
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
            model: 'meta-llama/llama-4-scout-17b-16e-instruct',
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
        'deepseek' => _ProviderConfig(
            id: 'deepseek',
            apiKey: apiKey,
            baseUrl: 'https://api.deepseek.com',
            model: 'deepseek-v4-flash',
          ),
        _ => null,
      };
      if (config == null) return 'Unknown provider.';
      if (config.isGemini) {
        await _sendGemini(
          config,
          'Reply with OK.',
          const [],
          'OK',
          maxOutputTokens: 32,
          maxHistoryMessages: 1,
          requestTimeout: const Duration(seconds: 10),
        );
      } else {
        await _sendOpenAiCompatible(
          config,
          const [
            {'role': 'user', 'content': 'Reply with OK.'},
          ],
          maxOutputTokens: 32,
          requestTimeout: const Duration(seconds: 10),
        );
      }
      return null;
    } on DioException catch (error) {
      return error.response?.data?.toString() ?? error.message;
    } catch (error) {
      return error.toString();
    }
  }

  Future<_ProviderResult> _sendOpenAiCompatible(
    _ProviderConfig provider,
    List<Map<String, String>> messages, {
    required int maxOutputTokens,
    required Duration requestTimeout,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '${provider.baseUrl}/chat/completions',
      options: Options(
        sendTimeout: _sendTimeout,
        receiveTimeout: requestTimeout,
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
        'max_tokens': maxOutputTokens,
        'stream': false,
      },
    ).timeout(requestTimeout + const Duration(seconds: 2));

    final usage = response.data?['usage'];
    return _ProviderResult(
      text: response.data?['choices']?[0]?['message']?['content']?.toString() ??
          'I am here. Could you say that again?',
      promptTokens: _asInt(usage?['prompt_tokens']),
      completionTokens: _asInt(usage?['completion_tokens']),
      totalTokens: _asInt(usage?['total_tokens']),
    );
  }

  Future<_ProviderResult> _sendGemini(
    _ProviderConfig provider,
    String systemPrompt,
    List<Message> history,
    String userText, {
    required int maxOutputTokens,
    required int maxHistoryMessages,
    required Duration requestTimeout,
  }) async {
    final transcript = StringBuffer(systemPrompt);
    for (final message
        in history.reversed.take(maxHistoryMessages).toList().reversed) {
      transcript
          .writeln('${message.isUser ? 'Student' : 'Eloq'}: ${message.text}');
    }
    transcript.writeln('Student: $userText');

    final response = await _dio.post<Map<String, dynamic>>(
      'https://generativelanguage.googleapis.com/v1beta/models/${provider.model}:generateContent?key=${provider.apiKey}',
      options: Options(
        sendTimeout: _sendTimeout,
        receiveTimeout: requestTimeout,
      ),
      data: {
        'contents': [
          {
            'parts': [
              {'text': transcript.toString()}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': maxOutputTokens,
        },
      },
    ).timeout(requestTimeout + const Duration(seconds: 2));

    final usage = response.data?['usageMetadata'];
    return _ProviderResult(
      text: response.data?['candidates']?[0]?['content']?['parts']?[0]?['text']
              ?.toString() ??
          'I am here. Could you say that again?',
      promptTokens: _asInt(usage?['promptTokenCount']),
      completionTokens: _asInt(usage?['candidatesTokenCount']),
      totalTokens: _asInt(usage?['totalTokenCount']),
    );
  }

  LlmResponse _parseResponse(
    String raw,
    String provider,
    String model, {
    required int promptTokens,
    required int completionTokens,
    required int totalTokens,
    required bool isTokenUsageEstimated,
  }) {
    const start = '|||CORRECTIONS|||';
    const end = '|||END|||';
    final startIndex = raw.indexOf(start);
    final endIndex = raw.indexOf(end);
    if (startIndex == -1 || endIndex == -1 || endIndex <= startIndex) {
      return LlmResponse(
        text: raw.trim(),
        provider: provider,
        model: model,
        promptTokens: promptTokens,
        completionTokens: completionTokens,
        totalTokens: totalTokens,
        isTokenUsageEstimated: isTokenUsageEstimated,
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
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      totalTokens: totalTokens,
      isTokenUsageEstimated: isTokenUsageEstimated,
      corrections: corrections,
    );
  }

  bool _isCoolingDown(String key) {
    final until = _cooldowns[key];
    if (until == null) return false;
    if (DateTime.now().isAfter(until)) {
      _cooldowns.remove(key);
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
      totalTokens: 0,
      isTokenUsageEstimated: true,
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

  int _asInt(Object? value) {
    return switch (value) {
      num number => number.toInt(),
      _ => 0,
    };
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

  List<_ProviderConfig> _groqProviders(
    AppSettings settings, {
    required bool preferLowLatency,
  }) {
    const scout = 'meta-llama/llama-4-scout-17b-16e-instruct';
    const maverick = 'meta-llama/llama-4-maverick-17b-128e-instruct';
    final models = settings.isGroqSmartMode && !preferLowLatency
        ? const [maverick, scout]
        : const [scout];
    return [
      for (final model in models)
        _ProviderConfig(
          id: 'groq',
          apiKey: settings.groqApiKey,
          baseUrl: 'https://api.groq.com/openai/v1',
          model: model,
        ),
    ];
  }

  bool _shouldCooldown(DioException error) {
    final status = error.response?.statusCode ?? 0;
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        status == 400 ||
        status == 401 ||
        status == 403 ||
        status == 404 ||
        status == 429 ||
        status >= 500;
  }

  String _failureText(_ProviderConfig provider, DioException error) {
    final status = error.response?.statusCode;
    if (status == 403 && provider.id == 'groq') {
      return '${provider.label} is not enabled for this Groq project.';
    }
    if (status == 429) {
      return '${provider.label} is rate limited.';
    }
    if (status != null) {
      return '${provider.label} returned HTTP $status.';
    }
    return '${provider.label}: ${error.message ?? error.type.name}.';
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

  String get cooldownKey => '$id:$model';

  String get label => switch (id) {
        'groq' when model.contains('maverick') => 'Groq Maverick',
        'groq' when model.contains('scout') => 'Groq Scout',
        'groq' => 'Groq',
        'cerebras' => 'Cerebras',
        'sambanova' => 'SambaNova',
        'gemini' => 'Gemini',
        'openrouter' => 'OpenRouter',
        'deepseek' => 'DeepSeek',
        _ => id,
      };
}

final llmRouterServiceProvider = Provider<LlmRouterService>((ref) {
  return LlmRouterService();
});
