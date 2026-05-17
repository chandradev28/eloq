import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/api_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../settings/providers/settings_provider.dart';
import '../../settings/widgets/api_key_guide.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _groqController = TextEditingController();
  final _xaiController = TextEditingController();
  String _level = 'beginner';
  bool _hydrated = false;

  @override
  void dispose() {
    _groqController.dispose();
    _xaiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    if (!_hydrated) {
      _groqController.text = settings.groqApiKey;
      _xaiController.text = settings.xaiApiKey;
      _level = settings.difficulty;
      _hydrated = true;
    }

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              children: [
                _Entrance(
                  index: 0,
                  child: _HeroPanel(
                    hasGroqKey: _groqController.text.trim().isNotEmpty,
                  ),
                ),
                const SizedBox(height: 18),
                _Entrance(
                  index: 1,
                  child: _ApiFieldCard(
                    controller: _groqController,
                    icon: Icons.key_rounded,
                    label: 'Groq API key',
                    helper: 'Voice transcription and chat responses',
                    provider: ApiProviders.groq,
                    onChanged: () => setState(() {}),
                  ),
                ),
                const SizedBox(height: 12),
                _Entrance(
                  index: 2,
                  child: _ApiFieldCard(
                    controller: _xaiController,
                    icon: Icons.graphic_eq_rounded,
                    label: 'xAI API key',
                    helper: 'Optional premium voice features later',
                    provider: ApiProviders.xai,
                    onChanged: () => setState(() {}),
                  ),
                ),
                const SizedBox(height: 20),
                _Entrance(
                  index: 3,
                  child: _LevelPicker(
                    selected: _level,
                    onChanged: (value) => setState(() => _level = value),
                  ),
                ),
                const SizedBox(height: 22),
                _Entrance(
                  index: 4,
                  child: FilledButton(
                    onPressed: _continue,
                    child: const Text('Continue'),
                  ),
                ),
                const SizedBox(height: 10),
                _Entrance(
                  index: 5,
                  child: TextButton(
                    onPressed: _continueWithoutKeys,
                    child: const Text('Continue without keys'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _continue() async {
    final current = ref.read(settingsProvider);
    await ref.read(settingsProvider.notifier).save(
          current.copyWith(
            groqApiKey: _groqController.text,
            xaiApiKey: _xaiController.text,
            difficulty: _level,
            hasCompletedOnboarding: true,
          ),
        );
    if (mounted) context.go('/home');
  }

  Future<void> _continueWithoutKeys() async {
    final current = ref.read(settingsProvider);
    await ref.read(settingsProvider.notifier).save(
          current.copyWith(
            difficulty: _level,
            hasCompletedOnboarding: true,
          ),
        );
    if (mounted) context.go('/home');
  }
}

class _Entrance extends StatelessWidget {
  const _Entrance({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.88, end: 1),
      duration: Duration(milliseconds: 420 + (index * 80)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.hasGroqKey});

  final bool hasGroqKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [Color(0xFF9A56F0), AppColors.purpleDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentPurple.withOpacity(0.24),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(
            right: -32,
            top: -34,
            child: _HeroRing(size: 126, opacity: 0.14),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mic_rounded, color: Colors.white),
                  ),
                  const Spacer(),
                  _SetupPill(
                    text: hasGroqKey ? 'API ready' : 'First setup',
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                'Set up Eloq',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                'Add your keys once. You can change everything later in Settings.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.78),
                  fontSize: 15,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroRing extends StatelessWidget {
  const _HeroRing({required this.size, required this.opacity});

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
          width: 16,
        ),
      ),
    );
  }
}

class _SetupPill extends StatelessWidget {
  const _SetupPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withOpacity(0.88),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ApiFieldCard extends StatelessWidget {
  const _ApiFieldCard({
    required this.controller,
    required this.icon,
    required this.label,
    required this.helper,
    required this.provider,
    required this.onChanged,
  });

  final TextEditingController controller;
  final IconData icon;
  final String label;
  final String helper;
  final ApiProviderInfo provider;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.line(context)),
      ),
      child: Column(
        children: [
          TextField(
            controller: controller,
            obscureText: true,
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(
              labelText: label,
              hintText: helper,
              prefixIcon: Icon(icon),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  helper,
                  style: TextStyle(
                    color: AppColors.secondaryText(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ProviderKeyButton(provider: provider, compact: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _LevelPicker extends StatelessWidget {
  const _LevelPicker({
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const levels = [
      ('beginner', 'Beginner'),
      ('intermediate', 'Intermediate'),
      ('advanced', 'Advanced'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'English level',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final level in levels) ...[
              Expanded(
                child: _LevelChip(
                  label: level.$2,
                  selected: selected == level.$1,
                  onTap: () => onChanged(level.$1),
                ),
              ),
              if (level != levels.last) const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accentPurple : AppColors.surface(context),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  selected ? AppColors.accentPurple : AppColors.line(context),
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.primaryText(context),
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
