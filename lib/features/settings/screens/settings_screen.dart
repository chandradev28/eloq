import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/app_settings.dart';
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
    if (!_hydrated) {
      _hydrate(settings);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _SectionTitle('API keys'),
          const ApiKeyGuide(),
          const SizedBox(height: 16),
          _KeyField(controller: _groq, label: 'Groq API key', required: true),
          _KeyField(controller: _cerebras, label: 'Cerebras API key'),
          _KeyField(controller: _sambanova, label: 'SambaNova API key'),
          _KeyField(controller: _gemini, label: 'Gemini API key'),
          _KeyField(controller: _openRouter, label: 'OpenRouter API key'),
          _KeyField(controller: _xai, label: 'xAI API key'),
          const SizedBox(height: 20),
          const _SectionTitle('Practice'),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'beginner', label: Text('Beginner')),
              ButtonSegment(value: 'intermediate', label: Text('Intermediate')),
              ButtonSegment(value: 'advanced', label: Text('Advanced')),
            ],
            selected: {settings.difficulty},
            onSelectionChanged: (selection) {
              ref.read(settingsProvider.notifier).update(
                    (current) => current.copyWith(difficulty: selection.first),
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
                    (current) => current.copyWith(voiceMode: selection.first),
                  );
            },
          ),
          const SizedBox(height: 16),
          Text('Speaking speed ${settings.speakingSpeed.toStringAsFixed(1)}x'),
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
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_rounded),
            label: const Text('Save settings'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content:
                        Text('Export will be added with history storage.')),
              );
            },
            icon: const Icon(Icons.file_download_rounded),
            label: const Text('Export progress'),
          ),
          const SizedBox(height: 18),
          const Text(
            'Premium xAI voice mode is scaffolded for Phase 4. Free mode uses Groq Whisper, the rotating LLM router, and device TTS.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
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
  });

  final TextEditingController controller;
  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        obscureText: true,
        decoration: InputDecoration(
          labelText: required ? '$label (required)' : label,
          prefixIcon: const Icon(Icons.key_rounded),
        ),
      ),
    );
  }
}
