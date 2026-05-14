import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/topics.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/conversation_provider.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/mic_button.dart';
import '../widgets/typing_indicator.dart';

class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key, required this.topicId});

  final String topicId;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topic = Topics.byId(widget.topicId);
    final state = ref.watch(conversationProvider(widget.topicId));
    final controller = ref.read(conversationProvider(widget.topicId).notifier);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(topic.name),
        actions: [
          IconButton(
            tooltip: 'Replay',
            onPressed: controller.replayLastAssistant,
            icon: const Icon(Icons.volume_up_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(18),
              itemCount: state.messages.length + (state.isThinking ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= state.messages.length) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: TypingIndicator(label: 'Eloq is thinking...'),
                  );
                }
                return ChatBubble(message: state.messages[index]);
              },
            ),
          ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                state.error!,
                style: const TextStyle(color: AppColors.accentRed),
              ),
            ),
          if (state.isTranscribing)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: TypingIndicator(label: 'Transcribing...'),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Type a message for quick testing',
                        ),
                        onSubmitted: (_) => _sendText(controller),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filled(
                      tooltip: 'Send',
                      onPressed: () => _sendText(controller),
                      icon: const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                MicButton(
                  isRecording: state.isRecording,
                  onPressed: controller.toggleRecording,
                ),
                const SizedBox(height: 8),
                Text(
                  state.isRecording ? 'Tap to stop' : 'Tap to speak',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _sendText(ConversationController controller) {
    final text = _textController.text;
    _textController.clear();
    controller.sendText(text);
  }
}
