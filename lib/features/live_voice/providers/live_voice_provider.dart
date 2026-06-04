import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/prompts.dart';
import '../../../core/constants/topics.dart';
import '../../../features/conversation/models/message.dart';
import '../../../features/settings/providers/settings_provider.dart';
import '../../../models/conversation_session.dart';
import '../../../services/audio_recorder_service.dart';
import '../../../services/gemini_live_service.dart';
import '../../../services/tts_service.dart';

class LiveVoiceState {
  const LiveVoiceState({
    this.topicId = 'free_talk',
    this.messages = const [],
    this.isConnecting = false,
    this.isSessionActive = false,
    this.isListening = false,
    this.isSpeaking = false,
    this.showTranscript = false,
    this.error,
    this.customPrompt = '',
    this.resumeContext = '',
    this.timerMinutes = 10,
    this.secondsRemaining = 600,
    this.isTimerRunning = false,
    this.timerFinished = false,
    this.userDraft = '',
    this.assistantDraft = '',
    this.isUsingFallback = false,
  });

  final String topicId;
  final List<Message> messages;
  final bool isConnecting;
  final bool isSessionActive;
  final bool isListening;
  final bool isSpeaking;
  final bool showTranscript;
  final String? error;
  final String customPrompt;
  final String resumeContext;
  final int timerMinutes;
  final int secondsRemaining;
  final bool isTimerRunning;
  final bool timerFinished;
  final String userDraft;
  final String assistantDraft;
  final bool isUsingFallback;

  LiveVoiceState copyWith({
    String? topicId,
    List<Message>? messages,
    bool? isConnecting,
    bool? isSessionActive,
    bool? isListening,
    bool? isSpeaking,
    bool? showTranscript,
    String? error,
    String? customPrompt,
    String? resumeContext,
    int? timerMinutes,
    int? secondsRemaining,
    bool? isTimerRunning,
    bool? timerFinished,
    String? userDraft,
    String? assistantDraft,
    bool? isUsingFallback,
    bool clearError = false,
  }) {
    return LiveVoiceState(
      topicId: topicId ?? this.topicId,
      messages: messages ?? this.messages,
      isConnecting: isConnecting ?? this.isConnecting,
      isSessionActive: isSessionActive ?? this.isSessionActive,
      isListening: isListening ?? this.isListening,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      showTranscript: showTranscript ?? this.showTranscript,
      error: clearError ? null : error ?? this.error,
      customPrompt: customPrompt ?? this.customPrompt,
      resumeContext: resumeContext ?? this.resumeContext,
      timerMinutes: timerMinutes ?? this.timerMinutes,
      secondsRemaining: secondsRemaining ?? this.secondsRemaining,
      isTimerRunning: isTimerRunning ?? this.isTimerRunning,
      timerFinished: timerFinished ?? this.timerFinished,
      userDraft: userDraft ?? this.userDraft,
      assistantDraft: assistantDraft ?? this.assistantDraft,
      isUsingFallback: isUsingFallback ?? this.isUsingFallback,
    );
  }
}

class LiveVoiceController extends StateNotifier<LiveVoiceState> {
  LiveVoiceController(this.ref) : super(const LiveVoiceState()) {
    _practiceStartedAt = DateTime.now();
    _historyStartedAt = _practiceStartedAt;
    _seedGreeting();
  }

  final Ref ref;
  final _uuid = const Uuid();

  late DateTime _practiceStartedAt;
  late DateTime _historyStartedAt;
  String _sessionId = const Uuid().v4();
  bool _sessionCounted = false;
  int _turnAudioBytes = 0;
  GeminiLiveUsage _latestUsage = const GeminiLiveUsage();

  StreamSubscription<GeminiLiveEvent>? _liveSubscription;
  StreamSubscription<Uint8List>? _audioSubscription;
  Timer? _timer;

  Future<void> applySetup({
    required String topicId,
    required int timerMinutes,
    required String customPrompt,
    required String resumeContext,
    bool restart = false,
  }) async {
    final nextTimer = timerMinutes.clamp(0, 120);
    if (nextTimer != state.timerMinutes) {
      _timer?.cancel();
    }

    state = state.copyWith(
      topicId: topicId,
      customPrompt: customPrompt.trim(),
      resumeContext: resumeContext.trim(),
      timerMinutes: nextTimer,
      secondsRemaining: nextTimer == state.timerMinutes
          ? state.secondsRemaining.clamp(0, _secondsForMinutes(nextTimer))
          : _secondsForMinutes(nextTimer),
      isTimerRunning:
          nextTimer == state.timerMinutes ? state.isTimerRunning : false,
      timerFinished:
          nextTimer == state.timerMinutes ? state.timerFinished : false,
      clearError: true,
    );

    if (restart || topicId != state.topicId) {
      await startNewSession(topicId: topicId);
    }
  }

  Future<void> toggleSession() async {
    if (state.isSessionActive || state.isConnecting) {
      await endSession();
      return;
    }
    await startSession();
  }

  void toggleTranscript() {
    state = state.copyWith(showTranscript: !state.showTranscript);
  }

  Future<void> startSession() async {
    final settings = ref.read(settingsProvider);
    if (state.timerFinished) {
      state = state.copyWith(
        error: 'Timer finished. Start a new live session to keep going.',
      );
      return;
    }
    if (settings.geminiApiKey.trim().isEmpty) {
      state = state.copyWith(
        error:
            'Add a Live Voice API key in Settings to use the AI speaking coach. Standard voice is still available.',
      );
      return;
    }

    await _stopRuntimeWork();
    await _liveSubscription?.cancel();
    final live = ref.read(geminiLiveServiceProvider);
    _liveSubscription = live.events.listen(_handleLiveEvent);

    state = state.copyWith(
      isConnecting: true,
      isSessionActive: true,
      isListening: false,
      isUsingFallback: false,
      showTranscript: true,
      clearError: true,
    );

    final topic = Topics.byId(state.topicId);
    final systemPrompt = Prompts.conversationSystemPrompt(
      level: settings.difficulty,
      topic: topic,
      extraInstructions: [
        'You are in Eloq Live Voice mode. Keep responses short, natural, and easy to say aloud.',
        'Ask only one follow-up question at a time.',
        state.customPrompt.trim(),
      ].where((item) => item.isNotEmpty).join('\n'),
      learnerContext: state.resumeContext,
    );

    try {
      await live.connect(
        apiKey: settings.geminiApiKey.trim(),
        systemInstruction: systemPrompt,
      );
    } catch (error) {
      state = state.copyWith(
        isConnecting: false,
        isSessionActive: false,
        error: error.toString(),
      );
    }
  }

  Future<void> endSession() async {
    _timer?.cancel();
    await _stopRuntimeWork();
    await _liveSubscription?.cancel();
    _liveSubscription = null;
    await ref.read(geminiLiveServiceProvider).disconnect();

    state = state.copyWith(
      isConnecting: false,
      isSessionActive: false,
      isListening: false,
      isSpeaking: false,
      isTimerRunning: false,
      userDraft: '',
      assistantDraft: '',
      clearError: true,
    );
  }

  Future<void> startNewSession({String? topicId}) async {
    await endSession();
    final now = DateTime.now();
    _practiceStartedAt = now;
    _historyStartedAt = now;
    _sessionId = _uuid.v4();
    _sessionCounted = false;
    _latestUsage = const GeminiLiveUsage();
    _turnAudioBytes = 0;
    state = state.copyWith(
      topicId: topicId ?? state.topicId,
      messages: const [],
      isConnecting: false,
      isSessionActive: false,
      isListening: false,
      isSpeaking: false,
      showTranscript: false,
      userDraft: '',
      assistantDraft: '',
      secondsRemaining: _secondsForMinutes(state.timerMinutes),
      isTimerRunning: false,
      timerFinished: false,
      clearError: true,
    );
    _seedGreeting();
  }

  Future<void> restoreSession(ConversationSession session) async {
    await endSession();
    _sessionId = session.id;
    _historyStartedAt = session.startedAt;
    _practiceStartedAt = DateTime.now();
    _sessionCounted = false;
    state = state.copyWith(
      topicId: session.topicId,
      messages: session.messages,
      showTranscript: true,
      userDraft: '',
      assistantDraft: '',
      secondsRemaining: _secondsForMinutes(state.timerMinutes),
      isTimerRunning: false,
      timerFinished: false,
      clearError: true,
    );
    if (session.messages.isEmpty) {
      _seedGreeting();
    }
  }

  Future<void> clearTranscript() async {
    await endSession();
    state = state.copyWith(
      messages: const [],
      showTranscript: false,
      userDraft: '',
      assistantDraft: '',
      clearError: true,
    );
    _seedGreeting();
  }

  Future<void> replayLastAssistant() async {
    final last = state.messages.where((message) => !message.isUser).lastOrNull;
    if (last == null) return;
    final settings = ref.read(settingsProvider);
    state = state.copyWith(isSpeaking: true, clearError: true);
    await ref
        .read(ttsServiceProvider)
        .speak(last.text, speed: settings.speakingSpeed);
    state = state.copyWith(isSpeaking: false);
    if (state.isSessionActive) {
      await _startMicStreaming();
    }
  }

  Future<void> useStandardFallback() async {
    await endSession();
    state = state.copyWith(isUsingFallback: true);
  }

  Future<void> _handleLiveEvent(GeminiLiveEvent event) async {
    switch (event) {
      case GeminiLiveConnected():
        state = state.copyWith(
          isConnecting: false,
          isSessionActive: true,
          isListening: true,
          clearError: true,
        );
        _ensureTimerRunning();
        await _startMicStreaming();
      case GeminiLiveInputTranscript(:final text):
        state = state.copyWith(
          userDraft: text,
          showTranscript: true,
          isListening: true,
        );
      case GeminiLiveOutputTranscript(:final text):
        _commitUserDraftIfNeeded();
        state = state.copyWith(
          assistantDraft: text,
          isListening: false,
          showTranscript: true,
        );
      case GeminiLiveUsageEvent(:final usage):
        _latestUsage = usage;
      case GeminiLiveTurnComplete():
        await _finalizeAssistantTurn();
      case GeminiLiveInterrupted():
        state = state.copyWith(
          assistantDraft: '',
          isListening: true,
        );
      case GeminiLiveError(:final message):
        state = state.copyWith(
          isConnecting: false,
          isListening: false,
          error: message,
        );
    }
  }

  Future<void> _startMicStreaming() async {
    if (!state.isSessionActive || state.isSpeaking || state.timerFinished) {
      return;
    }

    final recorder = ref.read(audioRecorderServiceProvider);
    final hasPermission = await recorder.hasPermission();
    if (!hasPermission) {
      state = state.copyWith(
        error: 'Microphone permission is needed to use Live Voice.',
        isListening: false,
      );
      return;
    }

    if (await recorder.isRecording()) {
      return;
    }

    _turnAudioBytes = 0;
    final stream = await recorder.startPcmStream();
    _audioSubscription = stream.listen(
      (chunk) {
        _turnAudioBytes += chunk.length;
        unawaited(ref.read(geminiLiveServiceProvider).sendAudioChunk(chunk));
      },
      onError: (Object error, StackTrace stackTrace) {
        state = state.copyWith(error: error.toString(), isListening: false);
      },
      onDone: () {
        state = state.copyWith(isListening: false);
      },
      cancelOnError: false,
    );

    state = state.copyWith(isListening: true, clearError: true);
  }

  Future<void> _stopMicStreaming() async {
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    final recorder = ref.read(audioRecorderServiceProvider);
    if (await recorder.isRecording()) {
      await recorder.stop();
    }
    await ref.read(geminiLiveServiceProvider).signalAudioStreamEnd();
    state = state.copyWith(isListening: false);
  }

  void _commitUserDraftIfNeeded() {
    final text = state.userDraft.trim();
    if (text.isEmpty) return;
    final message = Message(
      id: _uuid.v4(),
      role: MessageRole.user,
      text: text,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(
      messages: [...state.messages, message],
      userDraft: '',
      showTranscript: true,
    );
    final audioSeconds = (_turnAudioBytes / 32000).ceil().clamp(1, 3600);
    unawaited(
      ref.read(usageProvider.notifier).trackAudio(
            provider: 'gemini',
            model: GeminiLiveService.defaultModel,
            seconds: audioSeconds,
          ),
    );
    _turnAudioBytes = 0;
  }

  Future<void> _finalizeAssistantTurn() async {
    _commitUserDraftIfNeeded();
    final assistantText = state.assistantDraft.trim();
    if (assistantText.isEmpty) {
      if (state.isSessionActive && !state.timerFinished) {
        await _startMicStreaming();
      }
      return;
    }

    await _stopMicStreaming();
    final settings = ref.read(settingsProvider);
    final assistantMessage = Message(
      id: _uuid.v4(),
      role: MessageRole.assistant,
      text: assistantText,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(
      messages: [...state.messages, assistantMessage],
      assistantDraft: '',
      isSpeaking: true,
      showTranscript: true,
      clearError: true,
    );

    if (_latestUsage.totalTokens > 0) {
      await ref.read(usageProvider.notifier).trackChat(
            provider: 'gemini',
            model: GeminiLiveService.defaultModel,
            promptTokens: _latestUsage.promptTokens,
            completionTokens: _latestUsage.completionTokens,
            totalTokens: _latestUsage.totalTokens,
            isEstimated: false,
          );
      _latestUsage = const GeminiLiveUsage();
    }

    await ref.read(progressProvider.notifier).addMessageXp();
    await _countSessionOnce();
    await _saveSession();
    await ref
        .read(ttsServiceProvider)
        .speak(assistantText, speed: settings.speakingSpeed);
    state = state.copyWith(isSpeaking: false);

    if (state.isSessionActive && !state.timerFinished) {
      await _startMicStreaming();
    }
  }

  void _seedGreeting() {
    final topic = Topics.byId(state.topicId);
    final settings = ref.read(settingsProvider);
    final text = switch (settings.difficulty) {
      'advanced' =>
        'Live Voice is ready for ${topic.name.toLowerCase()}. Start the session and speak naturally. I will keep the conversation short, clear, and flowing.',
      'intermediate' =>
        'Live Voice is ready for ${topic.name.toLowerCase()}. Start the session and speak naturally. I will guide the conversation with short replies.',
      _ =>
        'Live Voice is ready for ${topic.name.toLowerCase()}. Start the session and speak. I will reply with simple English.',
    };

    state = state.copyWith(
      messages: [
        Message(
          id: _uuid.v4(),
          role: MessageRole.assistant,
          text: text,
          createdAt: DateTime.now(),
        ),
      ],
    );
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
        unawaited(endSession());
        state = state.copyWith(
          secondsRemaining: 0,
          isTimerRunning: false,
          timerFinished: true,
          error: 'Session timer finished. Start a new Live Voice session.',
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
        DateTime.now().difference(_practiceStartedAt).inSeconds.clamp(1, 7200);
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
      topicName: 'Live Voice - ${topic.name}',
      startedAt: _historyStartedAt,
      updatedAt: DateTime.now(),
      messages: state.messages,
      provider: 'live_voice',
    );
    await ref.read(historyProvider.notifier).upsert(session);
  }

  Future<void> _stopRuntimeWork() async {
    _timer?.cancel();
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    final recorder = ref.read(audioRecorderServiceProvider);
    if (await recorder.isRecording()) {
      await recorder.stop();
    }
    await ref.read(ttsServiceProvider).stop();
  }

  int _secondsForMinutes(int minutes) => minutes <= 0 ? 0 : minutes * 60;

  String formattedRemaining() {
    final total = state.secondsRemaining.clamp(0, 7200);
    final minutes = total ~/ 60;
    final seconds = total % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_stopRuntimeWork());
    unawaited(_liveSubscription?.cancel());
    unawaited(ref.read(geminiLiveServiceProvider).disconnect());
    super.dispose();
  }
}

final liveVoiceProvider =
    StateNotifierProvider.autoDispose<LiveVoiceController, LiveVoiceState>(
  (ref) => LiveVoiceController(ref),
);
