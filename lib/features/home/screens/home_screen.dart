import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../settings/providers/settings_provider.dart';
import '../widgets/topic_grid.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final progress = ref.watch(progressProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Eloq'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.go('/settings'),
            icon: const Icon(Icons.settings_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${progress.streak} day streak'),
                      Text('${progress.xp} XP'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    progress.level.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: progress.levelProgress),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => context.push('/conversation/restaurant'),
            icon: const Icon(Icons.mic_rounded),
            label: const Text('Start Talking'),
          ),
          if (!settings.hasGroqKey) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => context.go('/settings'),
              icon: const Icon(Icons.key_rounded),
              label: const Text('Add Groq key for real voice transcription'),
            ),
          ],
          const SizedBox(height: 26),
          Text(
            'Choose a topic',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 12),
          const TopicGrid(limit: 6),
          const SizedBox(height: 26),
          Text(
            'Recent conversations',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 12),
          const _EmptyRecent(),
        ],
      ),
    );
  }
}

class _EmptyRecent extends StatelessWidget {
  const _EmptyRecent();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Text(
        'Your first sessions will appear here.',
        style: TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}
