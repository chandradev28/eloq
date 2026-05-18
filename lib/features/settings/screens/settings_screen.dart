import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/app_settings.dart';
import '../../../models/api_usage.dart';
import '../../../services/llm_router_service.dart';
import '../providers/settings_provider.dart';
import '../widgets/api_key_guide.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _groq = TextEditingController();
  final _cerebras = TextEditingController();
  final _sambanova = TextEditingController();
  final _gemini = TextEditingController();
  final _openRouter = TextEditingController();
  final _xai = TextEditingController();
  bool _hydrated = false;
  final Set<String> _validating = {};
  final Map<String, String?> _validation = {};

  @override
  void dispose() {
    _groq.dispose();
    _cerebras.dispose();
    _sambanova.dispose();
    _gemini.dispose();
    _openRouter.dispose();
    _xai.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final usage = ref.watch(usageProvider);
    if (settings.isLoaded && !_hydrated) {
      _hydrate(settings);
    }

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 118),
              children: [
                Text(
                  'Settings',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 18),
                const _SectionTitle('Appearance'),
                _AppearanceCard(
                  isDarkMode: settings.isDarkMode,
                  onChanged: (value) {
                    ref.read(settingsProvider.notifier).update(
                          (current) => current.copyWith(isDarkMode: value),
                        );
                  },
                ),
                const SizedBox(height: 20),
                const _SectionTitle('Usage today'),
                _UsageCard(usage: usage),
                const SizedBox(height: 20),
                const _SectionTitle('API keys'),
                if (!settings.isLoaded) ...[
                  const LinearProgressIndicator(minHeight: 3),
                  const SizedBox(height: 12),
                ],
                const ApiKeyGuide(),
                const SizedBox(height: 16),
                _KeyField(
                  controller: _groq,
                  label: 'Groq API key',
                  required: true,
                  status: _validation['groq'],
                  validating: _validating.contains('groq'),
                  onTest: () => _testKey('groq', _groq.text),
                ),
                _KeyField(
                  controller: _cerebras,
                  label: 'Cerebras API key',
                  status: _validation['cerebras'],
                  validating: _validating.contains('cerebras'),
                  onTest: () => _testKey('cerebras', _cerebras.text),
                ),
                _KeyField(
                  controller: _sambanova,
                  label: 'SambaNova API key',
                  status: _validation['sambanova'],
                  validating: _validating.contains('sambanova'),
                  onTest: () => _testKey('sambanova', _sambanova.text),
                ),
                _KeyField(
                  controller: _gemini,
                  label: 'Gemini API key',
                  status: _validation['gemini'],
                  validating: _validating.contains('gemini'),
                  onTest: () => _testKey('gemini', _gemini.text),
                ),
                _KeyField(
                  controller: _openRouter,
                  label: 'OpenRouter API key',
                  status: _validation['openrouter'],
                  validating: _validating.contains('openrouter'),
                  onTest: () => _testKey('openrouter', _openRouter.text),
                ),
                _KeyField(controller: _xai, label: 'xAI API key'),
                const SizedBox(height: 20),
                const _SectionTitle('Practice'),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'beginner', label: Text('Beginner')),
                    ButtonSegment(
                        value: 'intermediate', label: Text('Intermediate')),
                    ButtonSegment(value: 'advanced', label: Text('Advanced')),
                  ],
                  selected: {settings.difficulty},
                  onSelectionChanged: (selection) {
                    ref.read(settingsProvider.notifier).update(
                          (current) =>
                              current.copyWith(difficulty: selection.first),
                        );
                  },
                ),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'free', label: Text('Free')),
                    ButtonSegment(value: 'premium', label: Text('Premium')),
                  ],
                  selected: {settings.voiceMode},
                  onSelectionChanged: (selection) {
                    ref.read(settingsProvider.notifier).update(
                          (current) =>
                              current.copyWith(voiceMode: selection.first),
                        );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Speaking speed ${settings.speakingSpeed.toStringAsFixed(1)}x',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Slider(
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  value: settings.speakingSpeed,
                  onChanged: (value) {
                    ref.read(settingsProvider.notifier).update(
                          (current) => current.copyWith(speakingSpeed: value),
                        );
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  'Daily goal ${settings.dailyGoalMinutes} min',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Slider(
                  min: 5,
                  max: 60,
                  divisions: 11,
                  value: settings.dailyGoalMinutes.toDouble().clamp(5, 60),
                  onChanged: (value) {
                    ref.read(settingsProvider.notifier).update(
                          (current) => current.copyWith(
                            dailyGoalMinutes: value.round(),
                          ),
                        );
                  },
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Save settings'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _exportProgress,
                  icon: const Icon(Icons.file_download_rounded),
                  label: const Text('Export progress'),
                ),
                const SizedBox(height: 18),
                Text(
                  'Premium xAI voice mode is scaffolded for Phase 4. Free mode uses Groq Whisper, the rotating LLM router, and device TTS.',
                  style: TextStyle(color: AppColors.secondaryText(context)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _hydrate(AppSettings settings) {
    _groq.text = settings.groqApiKey;
    _cerebras.text = settings.cerebrasApiKey;
    _sambanova.text = settings.sambanovaApiKey;
    _gemini.text = settings.geminiApiKey;
    _openRouter.text = settings.openRouterApiKey;
    _xai.text = settings.xaiApiKey;
    _hydrated = true;
  }

  Future<void> _save() async {
    final current = ref.read(settingsProvider);
    await ref.read(settingsProvider.notifier).save(
          current.copyWith(
            groqApiKey: _groq.text,
            cerebrasApiKey: _cerebras.text,
            sambanovaApiKey: _sambanova.text,
            geminiApiKey: _gemini.text,
            openRouterApiKey: _openRouter.text,
            xaiApiKey: _xai.text,
          ),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved')),
    );
  }

  Future<void> _testKey(String provider, String key) async {
    setState(() {
      _validating.add(provider);
      _validation.remove(provider);
    });
    final error = await ref.read(llmRouterServiceProvider).validateProvider(
          provider: provider,
          apiKey: key,
        );
    if (!mounted) return;
    setState(() {
      _validating.remove(provider);
      _validation[provider] = error == null ? 'Valid' : 'Invalid';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error == null
              ? '${provider.toUpperCase()} key works'
              : '${provider.toUpperCase()} key failed: $error',
        ),
      ),
    );
  }

  Future<void> _exportProgress() async {
    final settings = ref.read(settingsProvider);
    final progress = ref.read(progressProvider);
    final usage = ref.read(usageProvider);
    final sessions = ref.read(historyProvider);
    final export = {
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': {
        'difficulty': settings.difficulty,
        'voiceMode': settings.voiceMode,
        'speakingSpeed': settings.speakingSpeed,
        'dailyGoalMinutes': settings.dailyGoalMinutes,
        'isDarkMode': settings.isDarkMode,
      },
      'progress': progress.toJson(),
      'usageToday': usage.toJson(),
      'sessions': sessions.map((item) => item.toJson()).toList(),
    };

    const encoder = JsonEncoder.withIndent('  ');
    await Clipboard.setData(ClipboardData(text: encoder.convert(export)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Progress export copied')),
    );
  }
}

class _UsageCard extends StatelessWidget {
  const _UsageCard({required this.usage});

  final ApiUsage usage;

  @override
  Widget build(BuildContext context) {
    final audioMinutes = (usage.groqAudioSeconds / 60).floor();
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
          Row(
            children: [
              const Icon(Icons.speed_rounded, color: AppColors.accentPurple),
              const SizedBox(width: 10),
              Text(
                'Groq free usage',
                style: TextStyle(
                  color: AppColors.primaryText(context),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _UsageLine(
            label: 'Whisper audio',
            value: '$audioMinutes / 480 min',
            progress: usage.groqAudioSeconds / 28800,
          ),
          const SizedBox(height: 10),
          _UsageLine(
            label: 'Chat tokens',
            value: '${usage.groqChatTokens} / 100k',
            progress: usage.groqChatTokens / 100000,
          ),
          const SizedBox(height: 12),
          Text(
            '~${usage.estimatedGroqPracticeMinutesLeft} min practice left today',
            style: const TextStyle(
              color: AppColors.accentPurple,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageLine extends StatelessWidget {
  const _UsageLine({
    required this.label,
    required this.value,
    required this.progress,
  });

  final String label;
  final String value;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.secondaryText(context)),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 7,
            value: progress.clamp(0, 1),
          ),
        ),
      ],
    );
  }
}

class _AppearanceCard extends StatelessWidget {
  const _AppearanceCard({
    required this.isDarkMode,
    required this.onChanged,
  });

  final bool isDarkMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line(context)),
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
            child: Icon(
              isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              color: AppColors.accentPurple,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dark mode',
                  style: TextStyle(
                    color: AppColors.primaryText(context),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Use a darker purple interface.',
                  style: TextStyle(
                    color: AppColors.secondaryText(context),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: isDarkMode, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}

class _KeyField extends StatelessWidget {
  const _KeyField({
    required this.controller,
    required this.label,
    this.required = false,
    this.onTest,
    this.status,
    this.validating = false,
  });

  final TextEditingController controller;
  final String label;
  final bool required;
  final VoidCallback? onTest;
  final String? status;
  final bool validating;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            obscureText: true,
            decoration: InputDecoration(
              labelText: required ? '$label (required)' : label,
              prefixIcon: const Icon(Icons.key_rounded),
              suffixIcon: onTest == null
                  ? null
                  : IconButton(
                      tooltip: 'Test key',
                      onPressed: validating ? null : onTest,
                      icon: validating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.verified_rounded),
                    ),
            ),
          ),
          if (status != null) ...[
            const SizedBox(height: 6),
            Text(
              status!,
              style: TextStyle(
                color: status == 'Valid'
                    ? AppColors.accentGreen
                    : AppColors.accentRed,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
