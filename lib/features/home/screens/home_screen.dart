import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/topics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../../models/conversation_session.dart';
import '../../settings/providers/settings_provider.dart';
import '../../topics/models/topic.dart';
import '../widgets/topic_grid.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final progress = ref.watch(progressProvider);
    final sessions = ref.watch(historyProvider);
    final hours = (progress.minutesPracticed / 60).clamp(0, 99).toDouble();
    final shownHours = hours.toStringAsFixed(1);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: AppColors.isDark(context)
                ? const [
                    Color(0xFF3C216C),
                    Color(0xFF241A38),
                    AppColors.darkBg,
                  ]
                : const [
                    Color(0xFFBD8EFF),
                    Color(0xFFDCCBFF),
                    AppColors.bgPrimary,
                  ],
            stops: const [0, 0.34, 0.62],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 118),
                children: [
                  _HomeTopBar(
                    onSettings: () => context.go('/settings'),
                    onNotifications: () => _showNotifications(context),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          'Learn English\nwith AI.',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                height: 1.04,
                              ),
                        ),
                      ),
                      _StatusPill(text: settings.difficultyLabel),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.schedule_rounded,
                          value: shownHours,
                          unit: 'Hours',
                          label: 'Total Practice\nTime',
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.checklist_rounded,
                          value: progress.totalConversations.toString(),
                          unit: 'Sessions',
                          label: 'Completed\nConversations',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _DailyGoalCard(
                    practiced: progress.todayMinutesPracticed,
                    goal: settings.dailyGoalMinutes,
                  ),
                  const SizedBox(height: 16),
                  _HandsfreePracticeCard(
                    onTap: () => context.push('/handsfree'),
                  ),
                  const SizedBox(height: 16),
                  _StripedPracticeCard(
                    title: 'Speaking Practice',
                    subtitle: '${progress.minutesPracticed} minutes practiced',
                    chipText: '${progress.errorsCorrected} corrections',
                    onTap: () => _pickPracticeTopic(context),
                  ),
                  const SizedBox(height: 16),
                  _PurpleProgressCard(
                    progressValue: progress.levelProgress,
                    xp: progress.xp,
                    onTap: () => context.push('/conversation/free_talk'),
                  ),
                  if (!settings.hasGroqKey) ...[
                    const SizedBox(height: 14),
                    _KeyPrompt(onTap: () => context.go('/settings')),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'Choose a topic',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 12),
                  const TopicGrid(limit: 6),
                  const SizedBox(height: 24),
                  Text(
                    'Recent conversations',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => context.go('/history'),
                      icon: const Icon(Icons.history_rounded),
                      label: const Text('View all history'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (sessions.isEmpty)
                    const _EmptyRecent()
                  else
                    for (final session in sessions.take(3)) ...[
                      _RecentSessionCard(session: session),
                      const SizedBox(height: 10),
                    ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyGoalCard extends StatelessWidget {
  const _DailyGoalCard({
    required this.practiced,
    required this.goal,
  });

  final int practiced;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final progress =
        goal == 0 ? 0.0 : (practiced / goal).clamp(0, 1).toDouble();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Today',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const Spacer(),
              Text(
                '$practiced / $goal min',
                style: const TextStyle(
                  color: AppColors.accentPurple,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(minHeight: 8, value: progress),
          ),
        ],
      ),
    );
  }
}

Future<void> _pickPracticeTopic(BuildContext context) async {
  final selectedTopicId = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => const _TopicPickerSheet(),
  );
  if (selectedTopicId == null || !context.mounted) {
    return;
  }
  context.push('/conversation/$selectedTopicId');
}

void _showNotifications(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 96),
        child: SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.line(context)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Notifications',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppColors.primaryText(context),
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      tooltip: 'Close',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.softSurface(context),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.notifications_none_rounded,
                        color: AppColors.accentPurple,
                        size: 34,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'No notifications yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.secondaryText(context),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar({
    required this.onSettings,
    required this.onNotifications,
  });

  final VoidCallback onSettings;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoundAction(
          icon: Icons.menu_rounded,
          tooltip: 'Menu',
          onTap: onSettings,
        ),
        const SizedBox(width: 10),
        const BrandLogo(size: 34, borderRadius: 12),
        const SizedBox(width: 10),
        const Text(
          'Eloq',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        const Spacer(),
        _RoundAction(
          icon: Icons.notifications_none_rounded,
          tooltip: 'Notifications',
          onTap: onNotifications,
        ),
      ],
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
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
        color: AppColors.surface(context),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, color: AppColors.accentPurple, size: 22),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.purpleDeep,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.unit,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String unit;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 146,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.purpleDeep.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.softSurface(context),
              shape: BoxShape.circle,
            ),
            child:
                Icon(icon, color: AppColors.secondaryText(context), size: 18),
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: AppColors.primaryText(context),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  height: 0.95,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  unit,
                  style: TextStyle(
                    color: AppColors.secondaryText(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              color: AppColors.secondaryText(context),
              fontSize: 12,
              height: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StripedPracticeCard extends StatelessWidget {
  const _StripedPracticeCard({
    required this.title,
    required this.subtitle,
    required this.chipText,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String chipText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: CustomPaint(
          painter: _DiagonalStripePainter(),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface(context).withOpacity(
                AppColors.isDark(context) ? 0.74 : 0.48,
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              height: 1.08,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: AppColors.secondaryText(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SoftChip(text: chipText),
                    ],
                  ),
                ),
                IconButton.filled(
                  tooltip: 'Choose topic',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.accentPurple,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: onTap,
                  icon: const Icon(Icons.north_east_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HandsfreePracticeCard extends StatelessWidget {
  const _HandsfreePracticeCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Container(
          height: 204,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF0B0B10),
                Color(0xFF101827),
                Color(0xFF0E0E14),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: _SoftChip(text: 'Handsfree'),
                      ),
                      const Spacer(),
                      Text(
                        'Practice via\nspeaking',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              height: 1.04,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Voice-first practice with timer, transcript, and custom coach prompt.',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.68),
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const _HandsfreeVisualColumn(),
            ],
          ),
        ),
      ),
    );
  }
}

class _HandsfreeVisualColumn extends StatelessWidget {
  const _HandsfreeVisualColumn();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 118,
      child: Column(
        children: [
          SizedBox(height: 8),
          Align(
            alignment: Alignment.topCenter,
            child: _HandsfreeOrbPreview(),
          ),
          Spacer(),
          Align(
            alignment: Alignment.bottomRight,
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white,
              child: Icon(
                Icons.multitrack_audio_rounded,
                color: AppColors.accentPurple,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HandsfreeOrbPreview extends StatelessWidget {
  const _HandsfreeOrbPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
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
            color: const Color(0xFF1A8CFF).withOpacity(0.28),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 16,
            top: 26,
            child: Container(
              width: 52,
              height: 18,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.42),
                    Colors.white.withOpacity(0.08),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicPickerSheet extends StatelessWidget {
  const _TopicPickerSheet();

  @override
  Widget build(BuildContext context) {
    const topics = Topics.all;

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.78,
        ),
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.line(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose a topic',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Pick what you want to practice right now.',
                        style: TextStyle(
                          color: AppColors.secondaryText(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView.separated(
                itemCount: topics.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final topic = topics[index];
                  return _TopicPickerTile(topic: topic);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicPickerTile extends StatelessWidget {
  const _TopicPickerTile({required this.topic});

  final Topic topic;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.softSurface(context),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.of(context).pop(topic.id),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  shape: BoxShape.circle,
                ),
                child: Icon(topic.icon, color: AppColors.accentPurple),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic.name,
                      style: TextStyle(
                        color: AppColors.primaryText(context),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      topic.description,
                      style: TextStyle(
                        color: AppColors.secondaryText(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _SoftChip(text: topic.difficulty),
                  const SizedBox(height: 10),
                  const Icon(
                    Icons.north_east_rounded,
                    color: AppColors.accentPurple,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PurpleProgressCard extends StatelessWidget {
  const _PurpleProgressCard({
    required this.progressValue,
    required this.xp,
    required this.onTap,
  });

  final double progressValue;
  final int xp;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: Container(
        height: 150,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            colors: [AppColors.purpleDeep, AppColors.accentPurple],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentPurple.withOpacity(0.28),
              blurRadius: 26,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -16,
              top: -28,
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.25),
                    width: 6,
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Talk Your Way to\nFluency',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                ),
                const Spacer(),
                Text(
                  '$xp XP',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.68),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 7,
                    value: progressValue,
                    backgroundColor: Colors.white.withOpacity(0.24),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _KeyPrompt extends StatelessWidget {
  const _KeyPrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface(context),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.key_rounded, color: AppColors.accentPurple),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Add a Groq key for real voice transcription',
                  style: TextStyle(
                    color: AppColors.primaryText(context),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.secondaryText(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoftChip extends StatelessWidget {
  const _SoftChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.softSurface(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.accentPurple,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DiagonalStripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accentPurple.withOpacity(0.09)
      ..strokeWidth = 3;
    for (double x = -size.height; x < size.width + size.height; x += 12) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EmptyRecent extends StatelessWidget {
  const _EmptyRecent();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        'Your first sessions will appear here.',
        style: TextStyle(color: AppColors.secondaryText(context)),
      ),
    );
  }
}

class _RecentSessionCard extends StatelessWidget {
  const _RecentSessionCard({required this.session});

  final ConversationSession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.softSurface(context),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.forum_rounded,
              color: AppColors.accentPurple,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.topicName,
                  style: TextStyle(
                    color: AppColors.primaryText(context),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${session.userTurns} turns - ${session.correctionCount} corrections',
                  style: TextStyle(
                    color: AppColors.secondaryText(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Text(
            session.provider,
            style: const TextStyle(
              color: AppColors.accentPurple,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
