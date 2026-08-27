import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/prompts.dart';
import '../../../core/constants/topics.dart';
import '../../../core/utils/app_error_message.dart';
import '../../../features/conversation/models/message.dart';
import '../../../features/settings/providers/settings_provider.dart';
import '../../../models/conversation_session.dart';
import '../../../services/audio_recorder_service.dart';
import '../../../services/gemini_live_service.dart';
import '../../../services/native_audio_playback_service.dart';
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
  bool _disposed = false;
  bool _playedNativeAudioThisTurn = false;
  int _turnAudioBytes = 0;
  int _runtimeGeneration = 0;
  GeminiLiveUsage _latestUsage = const GeminiLiveUsage();
  Future<void> _eventQueue = Future<void>.value();

  StreamSubscription<GeminiLiveEvent>? _liveSubscription;
  StreamSubscription<Uint8List>? _audioSubscription;
  Timer? _timer;
  Timer? _turnFinalizeTimer;

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
    final generation = ++_runtimeGeneration;
    final live = ref.read(geminiLiveServiceProvider);
    _liveSubscription = live.events.listen((event) {
      final previousEvent = _eventQueue;
      _eventQueue = () async {
        try {
          await previousEvent;
          if (_isCurrent(generation)) {
            await _handleLiveEvent(event, generation);
          }
        } catch (error) {
          if (_isCurrent(generation)) {
            state = state.copyWith(error: AppErrorMessage.from(error));
          }
        }
      }();
    });

    state = state.copyWith(
      isConnecting: true,
      isSessionActive: true,
      isListening: false,
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
        voiceName: settings.voiceName.trim().isEmpty
            ? 'Kore'
            : settings.voiceName.trim(),
      );
    } catch (error) {
      if (!_isCurrent(generation)) return;
      await live.disconnect();
      state = state.copyWith(
        isConnecting: false,
        isSessionActive: false,
        error: AppErrorMessage.from(error),
      );
    }
  }

  Future<void> endSession() async {
    _runtimeGeneration++;
    _timer?.cancel();
    _turnFinalizeTimer?.cancel();
    await _stopRuntimeWork();
    await _liveSubscription?.cancel();
    _liveSubscription = null;
    await ref.read(geminiLiveServiceProvider).disconnect();

    if (_disposed) return;
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
    final generation = _runtimeGeneration;
    await _stopMicStreaming();
    await ref.read(nativeAudioPlaybackServiceProvider).stop();
    state = state.copyWith(isSpeaking: true, clearError: true);
    await ref
        .read(ttsServiceProvider)
        .speak(last.text, speed: settings.speakingSpeed);
    if (!_isCurrent(generation)) return;
    state = state.copyWith(isSpeaking: false);
    if (state.isSessionActive) {
      await _startMicStreaming();
    }
  }

  Future<void> _handleLiveEvent(
    GeminiLiveEvent event,
    int generation,
  ) async {
    if (!_isCurrent(generation)) return;
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
          userDraft: _mergeTranscript(state.userDraft, text),
          showTranscript: true,
          isListening: true,
        );
      case GeminiLiveOutputTranscript(:final text):
        _commitUserDraftIfNeeded();
        state = state.copyWith(
          assistantDraft: _mergeTranscript(state.assistantDraft, text),
          isListening: false,
          showTranscript: true,
        );
      case GeminiLiveAudioChunk(:final bytes):
        _playedNativeAudioThisTurn =
            await ref.read(nativeAudioPlaybackServiceProvider).write(bytes) ||
                _playedNativeAudioThisTurn;
        if (_isCurrent(generation)) {
          state = state.copyWith(isSpeaking: true, showTranscript: true);
        }
      case GeminiLiveUsageEvent(:final usage):
        _latestUsage = usage;
      case GeminiLiveTurnComplete():
        _scheduleTurnFinalization(generation);
      case GeminiLiveInterrupted():
        _turnFinalizeTimer?.cancel();
        await ref.read(nativeAudioPlaybackServiceProvider).stop();
        _playedNativeAudioThisTurn = false;
        state = state.copyWith(
          assistantDraft: '',
          isListening: true,
          isSpeaking: false,
        );
      case GeminiLiveError(:final message):
        await _stopRuntimeWork();
        await ref.read(geminiLiveServiceProvider).disconnect();
        state = state.copyWith(
          isConnecting: false,
          isSessionActive: false,
          isListening: false,
          isSpeaking: false,
          isTimerRunning: false,
          error: AppErrorMessage.from(message),
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
        state = state.copyWith(
          error: AppErrorMessage.from(error),
          isListening: false,
        );
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

  void _scheduleTurnFinalization(int generation) {
    _turnFinalizeTimer?.cancel();
    _turnFinalizeTimer = Timer(const Duration(milliseconds: 350), () {
      if (_isCurrent(generation)) {
        unawaited(_finalizeAssistantTurn(generation));
      }
    });
  }

  Future<void> _finalizeAssistantTurn(int generation) async {
    if (!_isCurrent(generation)) return;
    _commitUserDraftIfNeeded();
    final assistantText = state.assistantDraft.trim();
    if (assistantText.isEmpty) {
      state = state.copyWith(isSpeaking: false);
      _playedNativeAudioThisTurn = false;
      return;
    }

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
    if (!_isCurrent(generation)) return;
    if (!_playedNativeAudioThisTurn) {
      await _stopMicStreaming();
      await ref
          .read(ttsServiceProvider)
          .speak(assistantText, speed: settings.speakingSpeed);
    }
    _playedNativeAudioThisTurn = false;
    if (!_isCurrent(generation)) return;
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
    _turnFinalizeTimer?.cancel();
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    final recorder = ref.read(audioRecorderServiceProvider);
    if (await recorder.isRecording()) {
      await recorder.stop();
    }
    await ref.read(nativeAudioPlaybackServiceProvider).stop();
    await ref.read(ttsServiceProvider).stop();
  }

  String _mergeTranscript(String current, String incoming) {
    final existing = current.trim();
    final next = incoming.trim();
    if (next.isEmpty) return existing;
    if (existing.isEmpty || next.startsWith(existing)) return next;
    if (existing.startsWith(next) || existing.endsWith(next)) return existing;
    return '$existing $next';
  }

  bool _isCurrent(int generation) {
    return !_disposed && generation == _runtimeGeneration;
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
    _disposed = true;
    _runtimeGeneration++;
    _timer?.cancel();
    _turnFinalizeTimer?.cancel();
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
