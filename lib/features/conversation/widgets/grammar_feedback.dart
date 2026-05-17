import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/grammar_correction.dart';

class GrammarFeedback extends StatelessWidget {
  const GrammarFeedback({super.key, required this.corrections});

  final List<GrammarCorrection> corrections;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accentYellow.withOpacity(0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Grammar tip',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.accentYellow,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          for (final correction in corrections) ...[
            Text('"${correction.corrected}"'),
            const SizedBox(height: 4),
            Text(
              correction.explanation,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
