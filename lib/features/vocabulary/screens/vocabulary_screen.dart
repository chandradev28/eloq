import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/grammar_correction.dart';
import '../../settings/providers/settings_provider.dart';

class VocabularyScreen extends ConsumerWidget {
  const VocabularyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(historyProvider);
    final corrections = sessions.expand((item) => item.corrections).toList();

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 118),
              children: [
                Text(
                  'Review',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your saved corrections from real practice sessions.',
                  style: TextStyle(color: AppColors.secondaryText(context)),
                ),
                const SizedBox(height: 18),
                if (corrections.isEmpty)
                  const _EmptyCorrections()
                else
                  for (final correction in corrections.take(30)) ...[
                    _CorrectionCard(correction: correction),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CorrectionCard extends StatelessWidget {
  const _CorrectionCard({required this.correction});

  final GrammarCorrection correction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            correction.original,
            style: TextStyle(
              color: AppColors.secondaryText(context),
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            correction.corrected,
            style: TextStyle(
              color: AppColors.primaryText(context),
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            correction.explanation,
            style: TextStyle(color: AppColors.secondaryText(context)),
          ),
        ],
      ),
    );
  }
}

class _EmptyCorrections extends StatelessWidget {
  const _EmptyCorrections();

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
            Icons.lightbulb_rounded,
            color: AppColors.accentPurple,
            size: 42,
          ),
          const SizedBox(height: 12),
          Text(
            'Corrections will appear here after practice.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.secondaryText(context)),
          ),
        ],
      ),
    );
  }
}
