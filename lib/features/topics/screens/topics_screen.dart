import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../home/widgets/topic_grid.dart';

class TopicsScreen extends StatelessWidget {
  const TopicsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 118),
              children: [
                Text(
                  'Practice Topics',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose a real-life speaking scene.',
                  style: TextStyle(color: AppColors.secondaryText(context)),
                ),
                const SizedBox(height: 18),
                const TopicGrid(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
