import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/topics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/conversation_session.dart';
import '../providers/conversation_provider.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/mic_button.dart';
import '../widgets/typing_indicator.dart';

class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({
    super.key,
    required this.topicId,
    this.session,
  });

  final String topicId;
  final ConversationSession? session;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.session != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(conversationProvider(widget.topicId).notifier)
            .restoreSession(widget.session!);
      });
    }
  }

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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: SafeArea(
            child: Column(
              children: [
                _AssistantTopBar(
                  title: topic.name,
                  onBack: () => context.pop(),
                  onHistory: () => context.go('/history'),
                  onNewSession: controller.startNewSession,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                  child: _AssistantPanel(
                    isRecording: state.isRecording,
                    isTranscribing: state.isTranscribing,
                    onMic: controller.toggleRecording,
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 12),
                    children: [
                      for (final message in state.messages)
                        ChatBubble(message: message),
                      if (state.isThinking)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: TypingIndicator(label: 'Eloq is thinking...'),
                        ),
                    ],
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
                    padding: EdgeInsets.only(bottom: 8),
                    child: TypingIndicator(label: 'Transcribing...'),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          minLines: 1,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: 'Ask me anything...',
                          ),
                          onSubmitted: (_) => _sendText(controller),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filled(
                        tooltip: 'Send',
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.accentPurple,
                          foregroundColor: Colors.white,
                          fixedSize: const Size(50, 50),
                        ),
                        onPressed: () => _sendText(controller),
                        icon: const Icon(Icons.near_me_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _sendText(ConversationController controller) {
    final text = _textController.text;
    _textController.clear();
    controller.sendText(text);
  }
}

class _AssistantTopBar extends StatelessWidget {
  const _AssistantTopBar({
    required this.title,
    required this.onBack,
    required this.onHistory,
    required this.onNewSession,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onHistory;
  final VoidCallback onNewSession;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: onBack,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'History',
                onPressed: onHistory,
                icon: const Icon(Icons.history_rounded),
              ),
              IconButton(
                tooltip: 'New session',
                onPressed: onNewSession,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AssistantPanel extends StatelessWidget {
  const _AssistantPanel({
    required this.isRecording,
    required this.isTranscribing,
    required this.onMic,
  });

  final bool isRecording;
  final bool isTranscribing;
  final VoidCallback onMic;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 224,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [Color(0xFF9A56F0), AppColors.purpleDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentPurple.withOpacity(0.26),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(
            left: -28,
            top: -38,
            child: _SoftRing(size: 126, opacity: 0.08),
          ),
          const Positioned(
            right: -34,
            bottom: -44,
            child: _SoftRing(size: 150, opacity: 0.1),
          ),
          const Align(
            alignment: Alignment(0, -0.42),
            child: _AssistantOrb(),
          ),
          Align(
            alignment: const Alignment(0, 0.42),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PracticeStatusChip(
                  label: isRecording
                      ? 'Listening'
                      : isTranscribing
                          ? 'Transcribing'
                          : 'Ready to practice',
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.2),
                        blurRadius: 30,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: MicButton(isRecording: isRecording, onPressed: onMic),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PracticeStatusChip extends StatelessWidget {
  const _PracticeStatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withOpacity(0.86),
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SoftRing extends StatelessWidget {
  const _SoftRing({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withOpacity(opacity),
          width: 14,
        ),
      ),
    );
  }
}

class _AssistantOrb extends StatelessWidget {
  const _AssistantOrb();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OrbPainter(),
      child: const SizedBox(width: 102, height: 102),
    );
  }
}

class _OrbPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final fill = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withOpacity(0.34),
          Colors.white.withOpacity(0.06),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawCircle(center, size.width * 0.33, fill);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = Colors.white.withOpacity(0.16);
    for (var i = 0; i < 6; i++) {
      final inset = 12.0 + i * 2.5;
      final rect = Rect.fromLTWH(
        inset,
        18 + (i.isEven ? 0 : 4),
        size.width - inset * 2,
        size.height - 36,
      );
      canvas.drawOval(rect, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
