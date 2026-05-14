import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/topics.dart';
import '../../../features/settings/providers/settings_provider.dart';
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
    this.currentAudioPath,
    this.error,
  });

  final String topicId;
  final List<Message> messages;
  final bool isRecording;
  final bool isTranscribing;
  final bool isThinking;
  final String? currentAudioPath;
  final String? error;

  ConversationState copyWith({
    List<Message>? messages,
    bool? isRecording,
    bool? isTranscribing,
    bool? isThinking,
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
    _seedGreeting();
  }

  final Ref ref;
  final _uuid = const Uuid();

  Future<void> toggleRecording() async {
    if (state.isRecording) {
      await stopRecordingAndSend();
    } else {
      await startRecording();
    }
  }

  Future<void> startRecording() async {
    final recorder = ref.read(audioRecorderServiceProvider);
    final hasPermission = await recorder.hasPermission();
    if (!hasPermission) {
      state = state.copyWith(error: 'Microphone permission is needed to record.');
      return;
    }

    final path = await recorder.start();
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
          : 'I want to practice speaking English.';
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
            history: state.messages,
            userText: text,
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
      await ref.read(progressProvider.notifier).addMessageXp(
            corrections: response.corrections.length,
          );
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
    await ref.read(ttsServiceProvider).speak(last.text, speed: settings.speakingSpeed);
  }

  void _seedGreeting() {
    final topic = Topics.byId(state.topicId);
    final greeting = Message(
      id: _uuid.v4(),
      role: MessageRole.assistant,
      text: _greetingFor(topic.id),
      createdAt: DateTime.now(),
    );
    state = state.copyWith(messages: [greeting]);
  }

  String _greetingFor(String topicId) {
    final topic = Topics.byId(topicId);
    if (topicId == 'restaurant') {
      return 'Welcome. I will be your waiter today. What would you like to order?';
    }
    return 'Let us practice ${topic.name.toLowerCase()}. ${topic.prompt}';
  }
}

final conversationProvider = StateNotifierProvider.family
    .autoDispose<ConversationController, ConversationState, String>((ref, topicId) {
  return ConversationController(ref: ref, topicId: topicId);
});
