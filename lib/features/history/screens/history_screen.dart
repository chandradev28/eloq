import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/conversation_session.dart';
import '../../settings/providers/settings_provider.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(historyProvider);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 118),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'History',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                    ),
                    if (sessions.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear history',
                        onPressed: () => _confirmClear(context, ref),
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Saved from your real practice sessions. Tap to resume or delete any session.',
                  style: TextStyle(color: AppColors.secondaryText(context)),
                ),
                const SizedBox(height: 18),
                if (sessions.isEmpty)
                  const _EmptyHistory()
                else
                  for (final session in sessions) ...[
                    _SessionCard(
                      session: session,
                      onTap: () => _resumeSession(context, session),
                      onDelete: () => _confirmDelete(context, ref, session),
                    ),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear history?'),
        content:
            const Text('This removes saved conversations from this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (shouldClear != true) return;
    await ref.read(historyProvider.notifier).clear();
  }

  void _resumeSession(BuildContext context, ConversationSession session) {
    context.push('/conversation/${session.topicId}', extra: session);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ConversationSession session,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete session?'),
        content: Text(
          'Remove "${session.topicName}" from your saved history on this device?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;
    await ref.read(historyProvider.notifier).delete(session.id);
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.onTap,
    required this.onDelete,
  });

  final ConversationSession session;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('MMM d, h:mm a').format(session.updatedAt);

    return Material(
      color: AppColors.surface(context),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.line(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
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
                        const SizedBox(height: 3),
                        Text(
                          date,
                          style: TextStyle(
                            color: AppColors.secondaryText(context),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ProviderPill(text: session.provider),
                  IconButton(
                    tooltip: 'Delete session',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                session.preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.primaryText(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetricChip(
                    icon: Icons.keyboard_voice_rounded,
                    text: '${session.userTurns} turns',
                  ),
                  _MetricChip(
                    icon: Icons.lightbulb_rounded,
                    text: '${session.correctionCount} corrections',
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

class _ProviderPill extends StatelessWidget {
  const _ProviderPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.softSurface(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.accentPurple,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.softSurface(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.accentPurple),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: AppColors.primaryText(context),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.history_rounded,
            color: AppColors.accentPurple,
            size: 42,
          ),
          const SizedBox(height: 12),
          Text(
            'Your completed practice sessions will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.secondaryText(context)),
          ),
        ],
      ),
    );
  }
}
