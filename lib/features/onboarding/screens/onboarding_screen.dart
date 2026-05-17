import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/api_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/app_settings.dart';
import '../../settings/widgets/api_key_guide.dart';
import '../../settings/providers/settings_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _groqController = TextEditingController();
  final _xaiController = TextEditingController();
  String _level = 'beginner';

  @override
  void dispose() {
    _groqController.dispose();
    _xaiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    gradient: const LinearGradient(
                      colors: [AppColors.accentPurple, AppColors.purpleDeep],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Eloq',
                        style:
                            Theme.of(context).textTheme.displaySmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Practice English by speaking with a patient AI tutor.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.78),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _groqController,
                  decoration: const InputDecoration(
                    labelText: 'Groq API key',
                    hintText:
                        'Required for Whisper transcription and primary LLM',
                    prefixIcon: Icon(Icons.key_rounded),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: ProviderKeyButton(
                    provider: ApiProviders.groq,
                    compact: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _xaiController,
                  decoration: const InputDecoration(
                    labelText: 'xAI API key',
                    hintText: 'Optional premium voice key',
                    prefixIcon: Icon(Icons.graphic_eq_rounded),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: ProviderKeyButton(
                    provider: ApiProviders.xai,
                    compact: true,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'English level',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'beginner', label: Text('Beginner')),
                    ButtonSegment(
                        value: 'intermediate', label: Text('Intermediate')),
                    ButtonSegment(value: 'advanced', label: Text('Advanced')),
                  ],
                  selected: {_level},
                  onSelectionChanged: (selection) {
                    setState(() => _level = selection.first);
                  },
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _continue,
                  child: const Text('Continue'),
                ),
                TextButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('Try demo mode first'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _continue() async {
    final settings = AppSettings(
      groqApiKey: _groqController.text,
      xaiApiKey: _xaiController.text,
      difficulty: _level,
    );
    await ref.read(settingsProvider.notifier).save(settings);
    if (mounted) context.go('/home');
  }
}
