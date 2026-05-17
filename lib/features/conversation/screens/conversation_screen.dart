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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: SafeArea(
            child: Column(
              children: [
                _AssistantTopBar(
                  title: topic.name,
                  onBack: () => context.pop(),
                  onReplay: controller.replayLastAssistant,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                  child: _AssistantPanel(
                    isRecording: state.isRecording,
                    isTranscribing: state.isTranscribing,
                    onMic: controller.toggleRecording,
                    onReplay: controller.replayLastAssistant,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(22, 12, 22, 8),
                  child: _PromptMeter(),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                    children: [
                      const _PromptChips(),
                      const SizedBox(height: 12),
                      if (state.messages.isEmpty) const _RoadmapPreview(),
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
    required this.onReplay,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onReplay;

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
          IconButton(
            tooltip: 'Replay',
            onPressed: onReplay,
            icon: const Icon(Icons.more_vert_rounded),
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
    required this.onReplay,
  });

  final bool isRecording;
  final bool isTranscribing;
  final VoidCallback onMic;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 245,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [AppColors.accentPurple, AppColors.purpleDeep],
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
          const Positioned(left: 4, top: 2, child: _AvatarStack()),
          Positioned(
            right: 0,
            top: 0,
            child: _GlassIcon(
              icon: Icons.tune_rounded,
              tooltip: 'Assistant settings',
              onTap: () {},
            ),
          ),
          const Align(
            alignment: Alignment(0, -0.28),
            child: _AssistantOrb(),
          ),
          Align(
            alignment: const Alignment(0, 0.34),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                isRecording
                    ? 'Listening...'
                    : isTranscribing
                        ? 'Transcribing...'
                        : 'Hi! How can I assist?',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.78),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: MicButton(isRecording: isRecording, onPressed: onMic),
          ),
          Positioned(
            left: 8,
            bottom: 12,
            child: _GlassIcon(
              icon: Icons.photo_camera_outlined,
              tooltip: 'Camera',
              onTap: () {},
            ),
          ),
          Positioned(
            right: 8,
            bottom: 12,
            child: _GlassIcon(
              icon: Icons.restart_alt_rounded,
              tooltip: 'Replay',
              onTap: onReplay,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassIcon extends StatelessWidget {
  const _GlassIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withOpacity(0.12),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: Colors.white.withOpacity(0.72), size: 21),
          ),
        ),
      ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack();

  @override
  Widget build(BuildContext context) {
    const colors = [
      Color(0xFF2F2633),
      Color(0xFFFFC1A5),
      Color(0xFF7058C8),
    ];
    return SizedBox(
      width: 82,
      height: 36,
      child: Stack(
        children: [
          for (var i = 0; i < colors.length; i++)
            Positioned(
              left: i * 22,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: colors[i],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: Colors.white.withOpacity(0.9),
                  size: 18,
                ),
              ),
            ),
        ],
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

class _PromptMeter extends StatelessWidget {
  const _PromptMeter();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.auto_awesome_rounded,
            color: AppColors.textPrimary, size: 18),
        SizedBox(width: 6),
        Text(
          '16 Prompts left',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
        ),
        Spacer(),
        Text(
          'Powered by GPT-5',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

class _PromptChips extends StatelessWidget {
  const _PromptChips();

  @override
  Widget build(BuildContext context) {
    const chips = ['Week Summary', 'Create New plan', 'Apply Skill'];
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = index == 0;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.accentPurple : Colors.white,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              chips[index],
              style: TextStyle(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RoadmapPreview extends StatelessWidget {
  const _RoadmapPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Roadmap',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              Spacer(),
              Text(
                'Day   Week   Month   Year',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
          SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _RoadmapPill(
                  icon: Icons.lightbulb_outline_rounded,
                  text: 'Awaken Curiosity',
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _RoadmapPill(
                  icon: Icons.route_rounded,
                  text: 'Chart Your Path',
                  striped: true,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          _RoadmapPill(
            icon: Icons.school_rounded,
            text: 'Skill Test',
            compact: true,
          ),
        ],
      ),
    );
  }
}

class _RoadmapPill extends StatelessWidget {
  const _RoadmapPill({
    required this.icon,
    required this.text,
    this.striped = false,
    this.compact = false,
  });

  final IconData icon;
  final String text;
  final bool striped;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: striped ? _MiniStripePainter() : null,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 10,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: striped ? Colors.transparent : AppColors.lavenderSoft,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accentPurple.withOpacity(0.08)
      ..strokeWidth = 2;
    for (double x = -size.height; x < size.width + size.height; x += 8) {
      canvas.drawLine(
          Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
