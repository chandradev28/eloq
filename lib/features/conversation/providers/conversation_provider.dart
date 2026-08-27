import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/topics.dart';
import '../../../core/utils/app_error_message.dart';
import '../../../features/settings/providers/settings_provider.dart';
import '../../../models/conversation_session.dart';
import '../../../services/audio_recorder_service.dart';
import '../../../services/llm_router_service.dart';
import '../../../services/tts_service.dart';
import '../../../services/whisper_service.dart';
import '../models/message.dart';

class ConversationState {
  const ConversationState({
    required this.topicId,
    this.messages = const [],
    this.isRecording = false,
    this.isTranscribing = false,
    this.isThinking = false,
    this.isSpeaking = false,
    this.currentAudioPath,
    this.error,
  });

  final String topicId;
  final List<Message> messages;
  final bool isRecording;
  final bool isTranscribing;
  final bool isThinking;
  final bool isSpeaking;
  final String? currentAudioPath;
  final String? error;

  ConversationState copyWith({
    List<Message>? messages,
    bool? isRecording,
    bool? isTranscribing,
    bool? isThinking,
    bool? isSpeaking,
    String? currentAudioPath,
    String? error,
    bool clearAudioPath = false,
    bool clearError = false,
  }) {
    return ConversationState(
      topicId: topicId,
      messages: messages ?? this.messages,
      isRecording: isRecording ?? this.isRecording,
      isTranscribing: isTranscribing ?? this.isTranscribing,
      isThinking: isThinking ?? this.isThinking,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      currentAudioPath:
          clearAudioPath ? null : currentAudioPath ?? this.currentAudioPath,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class ConversationController extends StateNotifier<ConversationState> {
  ConversationController({
    required this.ref,
    required String topicId,
  }) : super(ConversationState(topicId: topicId)) {
    final now = DateTime.now();
    _sessionId = _uuid.v4();
    _practiceStartedAt = now;
    _historyStartedAt = now;
    _seedGreeting();
  }

  final Ref ref;
  final _uuid = const Uuid();
  late String _sessionId;
  late DateTime _practiceStartedAt;
  late DateTime _historyStartedAt;
  DateTime? _recordingStartedAt;
  bool _sessionCounted = false;
  bool _disposed = false;
  int _runtimeGeneration = 0;

  Future<void> restoreSession(ConversationSession session) async {
    _runtimeGeneration++;
    await _resetRuntimeState();
    _sessionId = session.id;
    _historyStartedAt = session.startedAt;
    _practiceStartedAt = DateTime.now();
    _sessionCounted = false;
    state = ConversationState(
      topicId: state.topicId,
      messages: session.messages,
    );
    if (session.messages.isEmpty) {
      _seedGreeting();
    }
  }

  Future<void> startNewSession() async {
    _runtimeGeneration++;
    await _resetRuntimeState();
    final now = DateTime.now();
    _sessionId = _uuid.v4();
    _historyStartedAt = now;
    _practiceStartedAt = now;
    _sessionCounted = false;
    state = ConversationState(topicId: state.topicId);
    _seedGreeting();
  }

  Future<void> toggleRecording() async {
    if (state.isTranscribing || state.isThinking) return;
    if (state.isRecording) {
      await stopRecordingAndSend();
    } else {
      if (state.isSpeaking) {
        await ref.read(ttsServiceProvider).stop();
        if (!_disposed) {
          state = state.copyWith(isSpeaking: false);
        }
      }
      await startRecording();
    }
  }

  Future<void> startRecording() async {
    if (!ref.read(settingsProvider).hasGroqKey) {
      state = state.copyWith(
        error:
            'Add your Groq API key in Settings to transcribe microphone audio.',
      );
      return;
    }
    final recorder = ref.read(audioRecorderServiceProvider);
    final hasPermission = await recorder.hasPermission();
    if (!hasPermission) {
      state =
          state.copyWith(error: 'Microphone permission is needed to record.');
      return;
    }

    final path = await recorder.start();
    _recordingStartedAt = DateTime.now();
    state = state.copyWith(
      isRecording: true,
      currentAudioPath: path,
      clearError: true,
    );
  }

  Future<void> stopRecordingAndSend() async {
    final generation = _runtimeGeneration;
    final recorder = ref.read(audioRecorderServiceProvider);
    final settings = ref.read(settingsProvider);
    final path = await recorder.stop() ?? state.currentAudioPath;
    if (!_isCurrent(generation)) return;
    state = state.copyWith(
      isRecording: false,
      isTranscribing: true,
      clearAudioPath: true,
      clearError: true,
    );

    try {
      if (path == null || path.isEmpty) {
        throw StateError('No audio file was captured.');
      }
      if (!settings.hasGroqKey) {
        throw StateError(
          'Add your Groq API key in Settings to transcribe microphone audio.',
        );
      }
      final text = await ref
          .read(whisperServiceProvider)
          .transcribe(apiKey: settings.groqApiKey, filePath: path)
          .timeout(const Duration(seconds: 16));
      if (!_isCurrent(generation)) return;
      final seconds = DateTime.now()
          .difference(_recordingStartedAt ?? DateTime.now())
          .inSeconds
          .clamp(1, 3600);
      await ref.read(usageProvider.notifier).trackAudio(
            provider: 'groq',
            model: 'whisper-large-v3-turbo',
            seconds: seconds,
          );
      await sendText(text);
    } catch (error) {
      if (!_isCurrent(generation)) return;
      state = state.copyWith(error: AppErrorMessage.from(error));
    } finally {
      if (_isCurrent(generation)) {
        state = state.copyWith(isTranscribing: false);
      }
    }
  }

  Future<void> sendText(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty || state.isThinking) return;
    final generation = _runtimeGeneration;

    final previousMessages = state.messages;
    final userMessage = Message(
      id: _uuid.v4(),
      role: MessageRole.user,
      text: text,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isThinking: true,
      clearError: true,
    );

    final settings = ref.read(settingsProvider);
    final topic = Topics.byId(state.topicId);
    try {
      final response = await ref.read(llmRouterServiceProvider).sendMessage(
            settings: settings,
            topic: topic,
            history: previousMessages,
            userText: text,
          );
      if (!_isCurrent(generation)) return;
      final assistantMessage = Message(
        id: _uuid.v4(),
        role: MessageRole.assistant,
        text: response.text,
        createdAt: DateTime.now(),
        corrections: response.corrections,
      );
      state = state.copyWith(
        messages: [...state.messages, assistantMessage],
        isThinking: false,
      );
      final isRealResponse =
          response.provider != 'demo' && response.provider != 'fallback';
      if (isRealResponse) {
        await ref.read(usageProvider.notifier).trackChat(
              provider: response.provider,
              model: response.model,
              promptTokens: response.promptTokens,
              completionTokens: response.completionTokens,
              totalTokens: response.totalTokens,
              isEstimated: response.isTokenUsageEstimated,
            );
        await ref.read(progressProvider.notifier).addMessageXp(
              corrections: response.corrections.length,
            );
        await _countSessionOnce();
        await _saveSession(response.provider);
      }
      if (!_isCurrent(generation)) return;
      state = state.copyWith(isSpeaking: true);
      await ref
          .read(ttsServiceProvider)
          .speak(response.text, speed: settings.speakingSpeed);
      if (_isCurrent(generation)) {
        state = state.copyWith(isSpeaking: false);
      }
    } catch (error) {
      if (!_isCurrent(generation)) return;
      state = state.copyWith(
        isThinking: false,
        isSpeaking: false,
        error: AppErrorMessage.from(error),
      );
    }
  }

  Future<void> replayLastAssistant() async {
    final settings = ref.read(settingsProvider);
    final last = state.messages.where((item) => !item.isUser).lastOrNull;
    if (last == null) return;
    final generation = _runtimeGeneration;
    state = state.copyWith(isSpeaking: true, clearError: true);
    try {
      await ref
          .read(ttsServiceProvider)
          .speak(last.text, speed: settings.speakingSpeed);
    } finally {
      if (_isCurrent(generation)) {
        state = state.copyWith(isSpeaking: false);
      }
    }
  }

  void _seedGreeting() {
    final topic = Topics.byId(state.topicId);
    final settings = ref.read(settingsProvider);
    final greeting = Message(
      id: _uuid.v4(),
      role: MessageRole.assistant,
      text: _greetingFor(topic.id, settings.difficulty),
      createdAt: DateTime.now(),
    );
    state = state.copyWith(messages: [greeting]);
  }

  String _greetingFor(String topicId, String difficulty) {
    final topic = Topics.byId(topicId);
    if (topicId == 'restaurant') {
      return switch (difficulty) {
        'advanced' =>
          'Good evening. I will be your waiter today. What would you like to order, or would you like to hear the specials first?',
        'intermediate' =>
          'Welcome. I will be your waiter today. What would you like to order?',
        _ => 'Hello. I am your waiter. What food would you like today?',
      };
    }
    return switch (difficulty) {
      'advanced' =>
        'Let us practice ${topic.name.toLowerCase()}. Feel free to answer in detail and keep the conversation going.',
      'intermediate' =>
        'Let us practice ${topic.name.toLowerCase()}. Answer naturally and I will help you continue.',
      _ =>
        'Let us practice ${topic.name.toLowerCase()}. Use simple English. I will help you.',
    };
  }

  Future<void> _countSessionOnce() async {
    if (_sessionCounted) return;
    _sessionCounted = true;
    final secondsPracticed =
        DateTime.now().difference(_practiceStartedAt).inSeconds.clamp(1, 7200);
    final minutesPracticed = ((secondsPracticed + 59) ~/ 60).clamp(1, 120);
    await ref
        .read(progressProvider.notifier)
        .completeConversation(minutesPracticed: minutesPracticed);
  }

  Future<void> _saveSession(String provider) async {
    final topic = Topics.byId(state.topicId);
    final session = ConversationSession(
      id: _sessionId,
      topicId: topic.id,
      topicName: topic.name,
      startedAt: _historyStartedAt,
      updatedAt: DateTime.now(),
      messages: state.messages,
      provider: provider,
    );
    await ref.read(historyProvider.notifier).upsert(session);
  }

  Future<void> _resetRuntimeState() async {
    final recorder = ref.read(audioRecorderServiceProvider);
    await ref.read(ttsServiceProvider).stop();
    if (await recorder.isRecording()) {
      await recorder.cancel();
    }
    _recordingStartedAt = null;
  }

  Future<void> endSession() async {
    _runtimeGeneration++;
    await _resetRuntimeState();
  }

  bool _isCurrent(int generation) {
    return !_disposed && generation == _runtimeGeneration;
  }

  @override
  void dispose() {
    _disposed = true;
    _runtimeGeneration++;
    final recorder = ref.read(audioRecorderServiceProvider);
    Future<void>(() async {
      if (await recorder.isRecording()) {
        await recorder.cancel();
      }
      await ref.read(ttsServiceProvider).stop();
    });
    super.dispose();
  }
}

final conversationProvider = StateNotifierProvider.family
    .autoDispose<ConversationController, ConversationState, String>(
        (ref, topicId) {
  return ConversationController(ref: ref, topicId: topicId);
});
