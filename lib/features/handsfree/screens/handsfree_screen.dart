import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/topics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../conversation/widgets/chat_bubble.dart';
import '../../conversation/widgets/typing_indicator.dart';
import '../providers/handsfree_provider.dart';

class HandsfreeScreen extends ConsumerStatefulWidget {
  const HandsfreeScreen({super.key});

  @override
  ConsumerState<HandsfreeScreen> createState() => _HandsfreeScreenState();
}

class _HandsfreeScreenState extends ConsumerState<HandsfreeScreen>
    with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(handsfreeProvider);
    final controller = ref.read(handsfreeProvider.notifier);
    final topic = Topics.byId(state.topicId);
    final lastUserMessage =
        state.messages.where((item) => item.isUser).lastOrNull;
    final idleLabel = state.timerFinished
        ? 'Session complete'
        : state.isRecording
            ? 'Listening'
            : state.isTranscribing
                ? 'Transcribing'
                : state.isThinking
                    ? 'Eloq is replying'
                    : 'Handsfree ready';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: SafeArea(
            child: Column(
              children: [
                _HandsfreeTopBar(
                  title: 'Handsfree',
                  onBack: () => context.pop(),
                  onOptions: () =>
                      _openSessionSetup(context, controller, state),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ModePill(icon: topic.icon, label: topic.name),
                        _ModePill(
                          icon: Icons.timer_outlined,
                          label: state.timerMinutes == 0
                              ? 'No timer'
                              : state.isTimerRunning || state.timerFinished
                                  ? controller.formattedRemaining()
                                  : '${state.timerMinutes} min timer',
                        ),
                        if (state.customPrompt.isNotEmpty)
                          const _ModePill(
                            icon: Icons.auto_awesome_rounded,
                            label: 'Custom coach',
                          ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: state.showTranscript
                        ? _TranscriptStage(
                            key: const ValueKey('transcript-stage'),
                            state: state,
                            lastUserMessage: lastUserMessage?.text,
                            pulse: _pulse,
                            onOrbTap: controller.toggleTranscript,
                          )
                        : _IdleStage(
                            key: const ValueKey('idle-stage'),
                            description: topic.description,
                            idleLabel: idleLabel,
                            pulse: _pulse,
                            active: state.isRecording ||
                                state.isThinking ||
                                state.isTranscribing,
                            onOrbTap: controller.toggleTranscript,
                          ),
                  ),
                ),
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
                    child: Text(
                      state.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.accentRed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (state.isTranscribing)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: TypingIndicator(label: 'Transcribing your audio...'),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                  child: Row(
                    children: [
                      _CircleActionButton(
                        icon: Icons.add_rounded,
                        tooltip: 'Session setup',
                        onTap: () =>
                            _openSessionSetup(context, controller, state),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _TypeBar(
                          controller: _textController,
                          enabled: !state.timerFinished,
                          onSend: () => _sendText(controller),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _CircleActionButton(
                        icon: Icons.volume_up_rounded,
                        tooltip: 'Replay last reply',
                        onTap: controller.replayLastAssistant,
                      ),
                      const SizedBox(width: 10),
                      _CircleActionButton(
                        icon: state.isRecording
                            ? Icons.stop_rounded
                            : Icons.mic_rounded,
                        tooltip: state.isRecording ? 'Stop listening' : 'Speak',
                        filled: true,
                        onTap: state.timerFinished
                            ? null
                            : controller.toggleRecording,
                      ),
                      const SizedBox(width: 10),
                      _CircleActionButton(
                        icon: Icons.close_rounded,
                        tooltip: 'Close',
                        onTap: () => context.pop(),
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

  Future<void> _openSessionSetup(
    BuildContext context,
    HandsfreeController controller,
    HandsfreeState state,
  ) async {
    final promptController = TextEditingController(text: state.customPrompt);
    final resumeController = TextEditingController(text: state.resumeContext);
    var selectedTopicId = state.topicId;
    var selectedTimer = state.timerMinutes;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SafeArea(
                top: false,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                  decoration: BoxDecoration(
                    color: AppColors.surface(context),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: AppColors.line(context)),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Handsfree setup',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Close',
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tune the timer, topic, coach prompt, and resume notes for this voice session.',
                          style: TextStyle(
                            color: AppColors.secondaryText(context),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Practice topic',
                          style: TextStyle(
                            color: AppColors.primaryText(context),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: selectedTopicId,
                          decoration: const InputDecoration(
                            hintText: 'Choose a topic',
                          ),
                          items: [
                            for (final topic in Topics.all)
                              DropdownMenuItem(
                                value: topic.id,
                                child: Text(topic.name),
                              ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setSheetState(() => selectedTopicId = value);
                          },
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Session timer',
                          style: TextStyle(
                            color: AppColors.primaryText(context),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final option in const [0, 5, 10, 15, 20, 30])
                              ChoiceChip(
                                selected: selectedTimer == option,
                                label: Text(
                                  option == 0 ? 'No timer' : '$option min',
                                ),
                                onSelected: (_) =>
                                    setSheetState(() => selectedTimer = option),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Coach prompt',
                          style: TextStyle(
                            color: AppColors.primaryText(context),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: promptController,
                          minLines: 3,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            hintText:
                                'Example: Be strict with grammar and keep replies short.',
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Resume / learner context',
                          style: TextStyle(
                            color: AppColors.primaryText(context),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: resumeController,
                          minLines: 3,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            hintText:
                                'Example: I am preparing for hotel interviews and want formal English.',
                          ),
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () async {
                                await controller.applySetup(
                                  topicId: selectedTopicId,
                                  timerMinutes: selectedTimer,
                                  customPrompt: promptController.text,
                                  resumeContext: resumeController.text,
                                );
                                if (!mounted) return;
                                await controller.clearTranscript();
                                if (sheetContext.mounted) {
                                  Navigator.of(sheetContext).pop();
                                }
                              },
                              icon: const Icon(Icons.layers_clear_rounded),
                              label: const Text('Clear transcript'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () async {
                                await controller.applySetup(
                                  topicId: selectedTopicId,
                                  timerMinutes: selectedTimer,
                                  customPrompt: promptController.text,
                                  resumeContext: resumeController.text,
                                  restart: true,
                                );
                                if (sheetContext.mounted) {
                                  Navigator.of(sheetContext).pop();
                                }
                              },
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('New session'),
                            ),
                            FilledButton.icon(
                              onPressed: () async {
                                await controller.applySetup(
                                  topicId: selectedTopicId,
                                  timerMinutes: selectedTimer,
                                  customPrompt: promptController.text,
                                  resumeContext: resumeController.text,
                                );
                                if (sheetContext.mounted) {
                                  Navigator.of(sheetContext).pop();
                                }
                              },
                              icon: const Icon(Icons.check_rounded),
                              label: const Text('Apply setup'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    promptController.dispose();
    resumeController.dispose();
  }

  void _sendText(HandsfreeController controller) {
    final text = _textController.text;
    _textController.clear();
    controller.sendText(text);
  }
}

class _IdleStage extends StatelessWidget {
  const _IdleStage({
    super.key,
    required this.description,
    required this.idleLabel,
    required this.pulse,
    required this.active,
    required this.onOrbTap,
  });

  final String description;
  final String idleLabel;
  final Animation<double> pulse;
  final bool active;
  final VoidCallback onOrbTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
      child: Column(
        children: [
          const Spacer(flex: 2),
          _StatusGlass(label: idleLabel),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.54),
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: onOrbTap,
            child: _VoiceOrb(
              pulse: pulse,
              large: true,
              active: active,
            ),
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }
}

class _TranscriptStage extends StatelessWidget {
  const _TranscriptStage({
    super.key,
    required this.state,
    required this.lastUserMessage,
    required this.pulse,
    required this.onOrbTap,
  });

  final HandsfreeState state;
  final String? lastUserMessage;
  final Animation<double> pulse;
  final VoidCallback onOrbTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 198),
          children: [
            if (lastUserMessage != null)
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 18),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    lastUserMessage!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            for (final message in state.messages) ChatBubble(message: message),
            if (state.isThinking)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: TypingIndicator(label: 'Eloq is thinking...'),
              ),
          ],
        ),
        Align(
          alignment: const Alignment(0, 0.86),
          child: GestureDetector(
            onTap: onOrbTap,
            child: _VoiceOrb(
              pulse: pulse,
              large: false,
              active:
                  state.isRecording || state.isThinking || state.isTranscribing,
            ),
          ),
        ),
      ],
    );
  }
}

class _HandsfreeTopBar extends StatelessWidget {
  const _HandsfreeTopBar({
    required this.title,
    required this.onBack,
    required this.onOptions,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onOptions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
      child: Row(
        children: [
          _CircleActionButton(
            icon: Icons.remove_rounded,
            tooltip: 'Back',
            compact: true,
            onTap: onBack,
          ),
          const SizedBox(width: 12),
          const BrandLogo(size: 40, borderRadius: 14),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          _CircleActionButton(
            icon: Icons.more_vert_rounded,
            tooltip: 'Options',
            compact: true,
            onTap: onOptions,
          ),
        ],
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white.withOpacity(0.88)),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.88),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusGlass extends StatelessWidget {
  const _StatusGlass({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _VoiceOrb extends StatelessWidget {
  const _VoiceOrb({
    required this.pulse,
    required this.large,
    required this.active,
  });

  final Animation<double> pulse;
  final bool large;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final size = large ? 182.0 : 90.0;

    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        final scale =
            active ? 1 + (pulse.value * 0.05) : 1 + (pulse.value * 0.016);
        return Transform.scale(
          scale: scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [
                  Color(0xFFDDF8FF),
                  Color(0xFF8DDAFF),
                  Color(0xFF0A75FF),
                ],
                stops: [0.1, 0.64, 1],
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      const Color(0xFF1A8CFF).withOpacity(active ? 0.44 : 0.24),
                  blurRadius: active ? 36 : 24,
                  spreadRadius: active ? 3 : 0,
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.52),
                          Colors.white.withOpacity(0.1),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  top: large ? 30 : 16,
                  child: Container(
                    width: size * 0.42,
                    height: size * 0.14,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.38),
                          Colors.white.withOpacity(0.08),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TypeBar extends StatelessWidget {
  const _TypeBar({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              textInputAction: TextInputAction.send,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Type',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          IconButton(
            tooltip: 'Send text',
            onPressed: enabled ? onSend : null,
            icon: const Icon(Icons.arrow_upward_rounded),
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.filled = false,
    this.compact = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool filled;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 52.0 : 56.0;
    final background = filled
        ? Colors.white
        : onTap == null
            ? Colors.white.withOpacity(0.04)
            : Colors.white.withOpacity(0.08);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              icon,
              color: filled ? Colors.black : Colors.white,
              size: compact ? 24 : 26,
            ),
          ),
        ),
      ),
    );
  }
}
