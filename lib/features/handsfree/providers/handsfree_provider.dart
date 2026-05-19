import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
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
    this.isSessionActive = false,
    this.isRecording = false,
    this.isTranscribing = false,
    this.isThinking = false,
    this.isSpeaking = false,
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
  final bool isSessionActive;
  final bool isRecording;
  final bool isTranscribing;
  final bool isThinking;
  final bool isSpeaking;
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
    bool? isSessionActive,
    bool? isRecording,
    bool? isTranscribing,
    bool? isThinking,
    bool? isSpeaking,
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
      isSessionActive: isSessionActive ?? this.isSessionActive,
      isRecording: isRecording ?? this.isRecording,
      isTranscribing: isTranscribing ?? this.isTranscribing,
      isThinking: isThinking ?? this.isThinking,
      isSpeaking: isSpeaking ?? this.isSpeaking,
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

  static const _voiceThresholdDb = -32.0;
  static const _silenceHold = Duration(milliseconds: 1400);
  static const _amplitudeInterval = Duration(milliseconds: 220);
  static const _maxUtterance = Duration(seconds: 18);
  static const _minSpeechLength = Duration(milliseconds: 700);

  final Ref ref;
  final Uuid _uuid = const Uuid();
  String _sessionId = const Uuid().v4();
  DateTime _startedAt = DateTime.now();
  DateTime? _recordingStartedAt;
  DateTime? _speechStartedAt;
  DateTime? _lastVoiceAt;
  bool _speechDetected = false;
  bool _sessionCounted = false;
  bool _isStoppingUtterance = false;
  Timer? _timer;
  StreamSubscription<Amplitude>? _amplitudeSubscription;

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
    await _stopHandsfreeSession(resetGreeting: false);
    state = state.copyWith(
      messages: const [],
      isSessionActive: false,
      showTranscript: false,
      clearAudioPath: true,
      clearError: true,
    );
    _seedGreeting();
  }

  Future<void> startNewSession({String? topicId}) async {
    await _stopHandsfreeSession(resetGreeting: false);
    _timer?.cancel();
    _sessionId = _uuid.v4();
    _startedAt = DateTime.now();
    _recordingStartedAt = null;
    _speechStartedAt = null;
    _lastVoiceAt = null;
    _speechDetected = false;
    _sessionCounted = false;
    _isStoppingUtterance = false;

    state = state.copyWith(
      topicId: topicId ?? state.topicId,
      messages: const [],
      isSessionActive: false,
      isRecording: false,
      isTranscribing: false,
      isThinking: false,
      isSpeaking: false,
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
    if (state.isSessionActive) {
      await _stopHandsfreeSession();
      return;
    }
    await startHandsfreeSession();
  }

  Future<void> startHandsfreeSession() async {
    if (state.timerFinished) {
      state = state.copyWith(
        error: 'Timer finished. Start a new voice session to keep practicing.',
      );
      return;
    }
    if (state.isSessionActive) return;

    state = state.copyWith(
      isSessionActive: true,
      clearError: true,
    );
    await _beginListeningCycle();
  }

  Future<void> replayLastAssistant() async {
    final settings = ref.read(settingsProvider);
    final last = state.messages.where((item) => !item.isUser).lastOrNull;
    if (last == null) return;

    await _stopCurrentRecording(discardRecording: true);
    state = state.copyWith(isSpeaking: true, clearError: true);
    await ref
        .read(ttsServiceProvider)
        .speak(last.text, speed: settings.speakingSpeed);
    state = state.copyWith(isSpeaking: false);

    if (state.isSessionActive && !state.timerFinished) {
      await _beginListeningCycle();
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

    await _stopCurrentRecording(discardRecording: true);
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
      showTranscript: true,
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
      state = state.copyWith(isSpeaking: true);
      await ref
          .read(ttsServiceProvider)
          .speak(response.text, speed: settings.speakingSpeed);
      state = state.copyWith(isSpeaking: false);
      if (state.isSessionActive && !state.timerFinished) {
        await _beginListeningCycle();
      }
    } catch (error) {
      state = state.copyWith(
        isThinking: false,
        isSpeaking: false,
        error: error.toString(),
      );
    }
  }

  String formattedRemaining() {
    final total = state.secondsRemaining.clamp(0, 7200);
    final minutes = total ~/ 60;
    final seconds = total % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _beginListeningCycle() async {
    if (!state.isSessionActive ||
        state.timerFinished ||
        state.isRecording ||
        state.isTranscribing ||
        state.isThinking ||
        state.isSpeaking) {
      return;
    }

    final recorder = ref.read(audioRecorderServiceProvider);
    final hasPermission = await recorder.hasPermission();
    if (!hasPermission) {
      state = state.copyWith(
        isSessionActive: false,
        error: 'Microphone permission is needed to start handsfree mode.',
      );
      return;
    }

    _ensureTimerRunning();
    await _stopCurrentRecording(discardRecording: true);
    final path = await recorder.start();
    _recordingStartedAt = DateTime.now();
    _speechStartedAt = null;
    _lastVoiceAt = null;
    _speechDetected = false;
    _isStoppingUtterance = false;
    state = state.copyWith(
      isRecording: true,
      currentAudioPath: path,
      clearError: true,
    );

    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = recorder
        .onAmplitudeChanged(_amplitudeInterval)
        .listen(_handleAmplitude);
  }

  void _handleAmplitude(Amplitude amplitude) {
    if (!_shouldTrackAmplitude) return;

    final now = DateTime.now();
    final currentDb = amplitude.current;
    if (currentDb > _voiceThresholdDb) {
      _speechDetected = true;
      _speechStartedAt ??= now;
      _lastVoiceAt = now;
    }

    final hasTimedOut = _recordingStartedAt != null &&
        now.difference(_recordingStartedAt!) >= _maxUtterance;
    final hasNaturalPause = _speechDetected &&
        _lastVoiceAt != null &&
        now.difference(_lastVoiceAt!) >= _silenceHold &&
        _speechStartedAt != null &&
        now.difference(_speechStartedAt!) >= _minSpeechLength;

    if (hasNaturalPause || hasTimedOut) {
      unawaited(_finalizeCurrentUtterance());
    }
  }

  bool get _shouldTrackAmplitude {
    return state.isSessionActive &&
        state.isRecording &&
        !_isStoppingUtterance &&
        !state.timerFinished;
  }

  Future<void> _finalizeCurrentUtterance() async {
    if (_isStoppingUtterance || !state.isRecording) return;
    _isStoppingUtterance = true;

    final recorder = ref.read(audioRecorderServiceProvider);
    final settings = ref.read(settingsProvider);
    final path = await recorder.stop() ?? state.currentAudioPath;
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;

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

      final audioSeconds = DateTime.now()
          .difference(_recordingStartedAt ?? DateTime.now())
          .inSeconds
          .clamp(1, 3600);
      if (settings.hasGroqKey) {
        await ref.read(usageProvider.notifier).trackAudio(
              provider: 'groq',
              model: 'whisper-large-v3-turbo',
              seconds: audioSeconds,
            );
      }

      final text = settings.hasGroqKey
          ? await ref
              .read(whisperServiceProvider)
              .transcribe(apiKey: settings.groqApiKey, filePath: path)
          : 'I want to keep practicing speaking English.';
      state = state.copyWith(isTranscribing: false);

      if (text.trim().length < 2) {
        if (state.isSessionActive && !state.timerFinished) {
          await _beginListeningCycle();
        }
        return;
      }

      await sendText(text);
    } catch (error) {
      state = state.copyWith(
        isTranscribing: false,
        showTranscript: true,
        error: error.toString(),
      );
    } finally {
      _recordingStartedAt = null;
      _speechStartedAt = null;
      _lastVoiceAt = null;
      _speechDetected = false;
      _isStoppingUtterance = false;
    }
  }

  Future<void> _stopHandsfreeSession({bool resetGreeting = false}) async {
    await _stopAudioWork(discardRecording: true);
    _timer?.cancel();
    state = state.copyWith(
      isSessionActive: false,
      isRecording: false,
      isTranscribing: false,
      isThinking: false,
      isSpeaking: false,
      isTimerRunning: false,
      clearAudioPath: true,
      clearError: true,
    );
    if (resetGreeting) {
      await clearTranscript();
    }
  }

  Future<void> _stopAudioWork({required bool discardRecording}) async {
    await _stopCurrentRecording(discardRecording: discardRecording);
    await ref.read(ttsServiceProvider).stop();
  }

  Future<void> _stopCurrentRecording({required bool discardRecording}) async {
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    _isStoppingUtterance = false;
    _speechDetected = false;
    _speechStartedAt = null;
    _lastVoiceAt = null;
    _recordingStartedAt = null;

    final recorder = ref.read(audioRecorderServiceProvider);
    if (discardRecording) {
      await recorder.cancel();
    } else {
      await recorder.stop();
    }
    state = state.copyWith(
      isRecording: false,
      clearAudioPath: true,
    );
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
        'Handsfree mode is ready for ${topic.name.toLowerCase()}. Tap the mic once, then speak naturally and I will keep the conversation moving.',
      'intermediate' =>
        'Handsfree mode is ready for ${topic.name.toLowerCase()}. Tap the mic once, then speak naturally and I will help you continue.',
      _ =>
        'Handsfree mode is ready for ${topic.name.toLowerCase()}. Tap the mic once and speak. I will help you.',
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
        unawaited(_stopHandsfreeSession());
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
    unawaited(_stopAudioWork(discardRecording: true));
    super.dispose();
  }
}

final handsfreeProvider =
    StateNotifierProvider.autoDispose<HandsfreeController, HandsfreeState>(
        (ref) {
  return HandsfreeController(ref);
});
