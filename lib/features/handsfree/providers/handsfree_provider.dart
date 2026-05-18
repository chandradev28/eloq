import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/topics.dart';
import '../../../features/conversation/models/message.dart';
import '../../../features/settings/providers/settings_provider.dart';
import '../../../models/conversation_session.dart';
import '../../../services/audio_recorder_service.dart';
import '../../../services/llm_router_service.dart';
import '../../../services/tts_service.dart';
import '../../../services/whisper_service.dart';

class HandsfreeState {
  const HandsfreeState({
    this.topicId = 'free_talk',
    this.messages = const [],
    this.isRecording = false,
    this.isTranscribing = false,
    this.isThinking = false,
    this.currentAudioPath,
    this.error,
    this.showTranscript = false,
    this.customPrompt = '',
    this.resumeContext = '',
    this.timerMinutes = 10,
    this.secondsRemaining = 600,
    this.isTimerRunning = false,
    this.timerFinished = false,
  });

  final String topicId;
  final List<Message> messages;
  final bool isRecording;
  final bool isTranscribing;
  final bool isThinking;
  final String? currentAudioPath;
  final String? error;
  final bool showTranscript;
  final String customPrompt;
  final String resumeContext;
  final int timerMinutes;
  final int secondsRemaining;
  final bool isTimerRunning;
  final bool timerFinished;

  HandsfreeState copyWith({
    String? topicId,
    List<Message>? messages,
    bool? isRecording,
    bool? isTranscribing,
    bool? isThinking,
    String? currentAudioPath,
    String? error,
    bool? showTranscript,
    String? customPrompt,
    String? resumeContext,
    int? timerMinutes,
    int? secondsRemaining,
    bool? isTimerRunning,
    bool? timerFinished,
    bool clearAudioPath = false,
    bool clearError = false,
  }) {
    return HandsfreeState(
      topicId: topicId ?? this.topicId,
      messages: messages ?? this.messages,
      isRecording: isRecording ?? this.isRecording,
      isTranscribing: isTranscribing ?? this.isTranscribing,
      isThinking: isThinking ?? this.isThinking,
      currentAudioPath:
          clearAudioPath ? null : currentAudioPath ?? this.currentAudioPath,
      error: clearError ? null : error ?? this.error,
      showTranscript: showTranscript ?? this.showTranscript,
      customPrompt: customPrompt ?? this.customPrompt,
      resumeContext: resumeContext ?? this.resumeContext,
      timerMinutes: timerMinutes ?? this.timerMinutes,
      secondsRemaining: secondsRemaining ?? this.secondsRemaining,
      isTimerRunning: isTimerRunning ?? this.isTimerRunning,
      timerFinished: timerFinished ?? this.timerFinished,
    );
  }
}

class HandsfreeController extends StateNotifier<HandsfreeState> {
  HandsfreeController(this.ref) : super(const HandsfreeState()) {
    _seedGreeting();
  }

  final Ref ref;
  final Uuid _uuid = const Uuid();
  String _sessionId = const Uuid().v4();
  DateTime _startedAt = DateTime.now();
  DateTime? _recordingStartedAt;
  bool _sessionCounted = false;
  Timer? _timer;

  void toggleTranscript() {
    state = state.copyWith(showTranscript: !state.showTranscript);
  }

  Future<void> applySetup({
    required String topicId,
    required int timerMinutes,
    required String customPrompt,
    required String resumeContext,
    bool restart = false,
  }) async {
    final trimmedPrompt = customPrompt.trim();
    final trimmedResume = resumeContext.trim();
    final nextTimer = timerMinutes.clamp(0, 120);
    final topicChanged = topicId != state.topicId;
    final timerChanged = nextTimer != state.timerMinutes;

    if (timerChanged) {
      _timer?.cancel();
    }

    state = state.copyWith(
      topicId: topicId,
      customPrompt: trimmedPrompt,
      resumeContext: trimmedResume,
      timerMinutes: nextTimer,
      secondsRemaining: timerChanged
          ? _secondsForMinutes(nextTimer)
          : state.secondsRemaining.clamp(0, _secondsForMinutes(nextTimer)),
      isTimerRunning: timerChanged ? false : state.isTimerRunning,
      timerFinished: timerChanged ? false : state.timerFinished,
      clearError: true,
    );

    if (topicChanged || restart) {
      await startNewSession(topicId: topicId);
    }
  }

  Future<void> clearTranscript() async {
    await ref.read(audioRecorderServiceProvider).stop();
    await ref.read(ttsServiceProvider).stop();
    state = state.copyWith(
      messages: const [],
      isRecording: false,
      isTranscribing: false,
      isThinking: false,
      showTranscript: false,
      clearAudioPath: true,
      clearError: true,
    );
    _seedGreeting();
  }

  Future<void> startNewSession({String? topicId}) async {
    _timer?.cancel();
    await ref.read(audioRecorderServiceProvider).stop();
    await ref.read(ttsServiceProvider).stop();
    _sessionId = _uuid.v4();
    _startedAt = DateTime.now();
    _recordingStartedAt = null;
    _sessionCounted = false;

    state = state.copyWith(
      topicId: topicId ?? state.topicId,
      messages: const [],
      isRecording: false,
      isTranscribing: false,
      isThinking: false,
      showTranscript: false,
      secondsRemaining: _secondsForMinutes(state.timerMinutes),
      isTimerRunning: false,
      timerFinished: false,
      clearAudioPath: true,
      clearError: true,
    );
    _seedGreeting();
  }

  Future<void> toggleRecording() async {
    if (state.isRecording) {
      await stopRecordingAndSend();
    } else {
      await startRecording();
    }
  }

  Future<void> startRecording() async {
    if (state.timerFinished) {
      state = state.copyWith(
        error: 'Timer finished. Start a new voice session to keep practicing.',
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

    _ensureTimerRunning();
    final path = await recorder.start();
    _recordingStartedAt = DateTime.now();
    state = state.copyWith(
      isRecording: true,
      currentAudioPath: path,
      clearError: true,
    );
  }

  Future<void> stopRecordingAndSend() async {
    final recorder = ref.read(audioRecorderServiceProvider);
    final settings = ref.read(settingsProvider);
    final path = await recorder.stop() ?? state.currentAudioPath;
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
      final text = settings.hasGroqKey
          ? await ref
              .read(whisperServiceProvider)
              .transcribe(apiKey: settings.groqApiKey, filePath: path)
          : 'I want to keep practicing speaking English.';
      if (settings.hasGroqKey) {
        final seconds = DateTime.now()
            .difference(_recordingStartedAt ?? DateTime.now())
            .inSeconds
            .clamp(1, 3600);
        await ref.read(usageProvider.notifier).trackAudio(
              provider: 'groq',
              model: 'whisper-large-v3-turbo',
              seconds: seconds,
            );
      }
      await sendText(text);
    } catch (error) {
      state = state.copyWith(error: error.toString());
    } finally {
      state = state.copyWith(isTranscribing: false);
    }
  }

  Future<void> sendText(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty) return;
    if (state.timerFinished) {
      state = state.copyWith(
        error: 'Timer finished. Start a new voice session to keep practicing.',
      );
      return;
    }

    _ensureTimerRunning();
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
            extraInstructions: state.customPrompt,
            learnerContext: state.resumeContext,
          );
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
      if (response.provider != 'demo' && response.provider != 'fallback') {
        await ref.read(usageProvider.notifier).trackChat(
              provider: response.provider,
              model: response.model,
              estimatedTokens: response.estimatedTokens,
            );
      }
      await ref.read(progressProvider.notifier).addMessageXp(
            corrections: response.corrections.length,
          );
      await _countSessionOnce();
      await _saveSession();
      await ref
          .read(ttsServiceProvider)
          .speak(response.text, speed: settings.speakingSpeed);
    } catch (error) {
      state = state.copyWith(isThinking: false, error: error.toString());
    }
  }

  Future<void> replayLastAssistant() async {
    final settings = ref.read(settingsProvider);
    final last = state.messages.where((item) => !item.isUser).lastOrNull;
    if (last == null) return;
    await ref
        .read(ttsServiceProvider)
        .speak(last.text, speed: settings.speakingSpeed);
  }

  String formattedRemaining() {
    final total = state.secondsRemaining.clamp(0, 7200);
    final minutes = total ~/ 60;
    final seconds = total % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
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
          'Good evening. This is your handsfree restaurant practice. I will be your waiter today. Would you like to hear the specials or place an order right away?',
        'intermediate' =>
          'Welcome to your handsfree restaurant practice. I will be your waiter today. What would you like to order?',
        _ =>
          'Hello. This is handsfree restaurant practice. I am your waiter. What food would you like today?',
      };
    }
    return switch (difficulty) {
      'advanced' =>
        'Handsfree mode is ready for ${topic.name.toLowerCase()}. Speak naturally and I will keep the conversation moving with rich follow-up questions.',
      'intermediate' =>
        'Handsfree mode is ready for ${topic.name.toLowerCase()}. Speak naturally and I will help you continue the conversation.',
      _ =>
        'Handsfree mode is ready for ${topic.name.toLowerCase()}. Use simple English and I will help you.',
    };
  }

  void _ensureTimerRunning() {
    if (state.timerMinutes <= 0 ||
        state.timerFinished ||
        state.isTimerRunning) {
      return;
    }

    state = state.copyWith(
      isTimerRunning: true,
      secondsRemaining: state.secondsRemaining == 0
          ? _secondsForMinutes(state.timerMinutes)
          : state.secondsRemaining,
    );
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final next = state.secondsRemaining - 1;
      if (next <= 0) {
        timer.cancel();
        ref.read(ttsServiceProvider).stop();
        state = state.copyWith(
          secondsRemaining: 0,
          isTimerRunning: false,
          timerFinished: true,
          error:
              'Session timer finished. Start a new session when you are ready.',
        );
        return;
      }
      state = state.copyWith(secondsRemaining: next);
    });
  }

  Future<void> _countSessionOnce() async {
    if (_sessionCounted) return;
    _sessionCounted = true;
    final secondsPracticed =
        DateTime.now().difference(_startedAt).inSeconds.clamp(1, 7200);
    final minutesPracticed = ((secondsPracticed + 59) ~/ 60).clamp(1, 120);
    await ref
        .read(progressProvider.notifier)
        .completeConversation(minutesPracticed: minutesPracticed);
  }

  Future<void> _saveSession() async {
    final topic = Topics.byId(state.topicId);
    final session = ConversationSession(
      id: _sessionId,
      topicId: topic.id,
      topicName: topic.name,
      startedAt: _startedAt,
      updatedAt: DateTime.now(),
      messages: state.messages,
      provider: 'Handsfree',
    );
    await ref.read(historyProvider.notifier).upsert(session);
  }

  int _secondsForMinutes(int minutes) => minutes <= 0 ? 0 : minutes * 60;

  @override
  void dispose() {
    _timer?.cancel();
    ref.read(ttsServiceProvider).stop();
    ref.read(audioRecorderServiceProvider).stop();
    super.dispose();
  }
}

final handsfreeProvider =
    StateNotifierProvider.autoDispose<HandsfreeController, HandsfreeState>(
        (ref) {
  return HandsfreeController(ref);
});
