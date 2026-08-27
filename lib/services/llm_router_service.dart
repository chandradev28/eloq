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
    this.notice,
    this.corrections = const [],
  });

  final String text;
  final String provider;
  final String model;
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final bool isTokenUsageEstimated;
  final String? notice;
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
      ..._groqProviders(settings),
      _ProviderConfig(
        id: 'gemini',
        apiKey: settings.geminiApiKey,
        baseUrl: '',
        model: 'gemini-3.5-flash-lite',
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
    final blockedProviderIds = <String>{};
    final requestClock = Stopwatch()..start();

    for (final provider in orderedProviders) {
      if (!provider.isReady ||
          blockedProviderIds.contains(provider.id) ||
          _isCoolingDown(provider.cooldownKey)) {
        continue;
      }
      final remaining = requestTimeout - requestClock.elapsed;
      if (remaining <= Duration.zero) {
        failures.add('The AI request timed out.');
        break;
      }
      try {
        final result = provider.isGemini
            ? await _sendGemini(
                provider,
                systemPrompt,
                history,
                userText,
                maxOutputTokens: maxOutputTokens,
                maxHistoryMessages: maxHistoryMessages,
                requestTimeout: remaining,
              )
            : await _sendOpenAiCompatible(
                provider,
                openAiMessages,
                maxOutputTokens: maxOutputTokens,
                requestTimeout: remaining,
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
        if (_isProviderWideFailure(error)) {
          blockedProviderIds.add(provider.id);
        }
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
      notice: failures.isEmpty
          ? 'No configured AI provider was available.'
          : failures.first,
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
            model: 'openai/gpt-oss-20b',
          ),
        'gemini' => _ProviderConfig(
            id: 'gemini',
            apiKey: apiKey,
            baseUrl: '',
            model: 'gemini-3.5-flash-lite',
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
        'max_completion_tokens': maxOutputTokens,
        ..._groqReasoningOptions(provider.model),
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
    final trimmedRaw = raw.trim();
    final startIndex = trimmedRaw.indexOf(start);
    final endIndex = trimmedRaw.indexOf(end);
    if (startIndex == -1) {
      return LlmResponse(
        text: trimmedRaw.isEmpty
            ? 'I am here. Could you say that again?'
            : trimmedRaw,
        provider: provider,
        model: model,
        promptTokens: promptTokens,
        completionTokens: completionTokens,
        totalTokens: totalTokens,
        isTokenUsageEstimated: isTokenUsageEstimated,
      );
    }

    final spokenText = trimmedRaw.substring(0, startIndex).trim();
    var corrections = <GrammarCorrection>[];
    if (endIndex > startIndex) {
      final jsonText =
          trimmedRaw.substring(startIndex + start.length, endIndex).trim();
      try {
        final decoded = jsonDecode(jsonText);
        corrections = decoded is List
            ? decoded
                .whereType<Map>()
                .map((item) =>
                    GrammarCorrection.fromJson(Map<String, dynamic>.from(item)))
                .toList()
            : <GrammarCorrection>[];
      } on FormatException {
        corrections = <GrammarCorrection>[];
      }
    }

    return LlmResponse(
      text: spokenText.isEmpty
          ? 'I am here. Could you say that again?'
          : spokenText,
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

  Map<String, Object> _groqReasoningOptions(String model) {
    if (!model.startsWith('openai/gpt-oss-')) return const {};
    return {
      'reasoning_effort': model == 'openai/gpt-oss-20b' ? 'low' : 'medium',
      'include_reasoning': false,
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

  List<_ProviderConfig> _groqProviders(AppSettings settings) {
    if (!settings.hasGroqKey) return const [];

    const fastModels = ['openai/gpt-oss-20b'];
    const smartModels = [
      'openai/gpt-oss-120b',
      'openai/gpt-oss-20b',
    ];

    return [
      for (final model in settings.isGroqSmartMode ? smartModels : fastModels)
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

  bool _isProviderWideFailure(DioException error) {
    final status = error.response?.statusCode ?? 0;
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.connectionError ||
        status == 401 ||
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
        'groq' when model == 'openai/gpt-oss-120b' => 'Groq Smart',
        'groq' when model == 'openai/gpt-oss-20b' => 'Groq Fast',
        'groq' => 'Groq',
        'gemini' => 'Gemini',
        'openrouter' => 'OpenRouter',
        'deepseek' => 'DeepSeek',
        _ => id,
      };
}

final llmRouterServiceProvider = Provider<LlmRouterService>((ref) {
  return LlmRouterService();
});
