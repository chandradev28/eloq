import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/api_providers.dart';
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
    final premiumUnlocked = _xai.text.trim().isNotEmpty || settings.hasXaiKey;
    final selectedVoiceMode = premiumUnlocked ? settings.voiceMode : 'free';
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
                _UsageCard(
                  usage: usage,
                  settings: settings,
                ),
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
                _KeyField(
                  controller: _xai,
                  label: 'xAI API key',
                  helper: 'Unlocks the Premium voice mode option.',
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
                const SizedBox(height: 20),
                const _SectionTitle('Practice'),
                _PracticeModeCard(
                  title: 'English level',
                  subtitle: settings.difficultySummary,
                  children: [
                    _ChoiceRow(
                      options: const [
                        ('beginner', 'Beginner'),
                        ('intermediate', 'Intermediate'),
                        ('advanced', 'Advanced'),
                      ],
                      selected: settings.difficulty,
                      onChanged: (value) {
                        ref.read(settingsProvider.notifier).update(
                              (current) => current.copyWith(difficulty: value),
                            );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _PracticeModeCard(
                  title: 'Voice mode',
                  subtitle: premiumUnlocked
                      ? 'Premium is unlocked because an xAI key is present. Free mode is still the only fully implemented runtime path today.'
                      : 'Free mode uses Groq Whisper, the router, and device TTS. Add an xAI key to unlock the Premium option.',
                  children: [
                    _ChoiceRow(
                      options: const [
                        ('free', 'Free'),
                        ('premium', 'Premium'),
                      ],
                      selected: selectedVoiceMode,
                      onChanged: (value) {
                        if (value == 'premium' && !premiumUnlocked) return;
                        ref.read(settingsProvider.notifier).update(
                              (current) => current.copyWith(voiceMode: value),
                            );
                      },
                      isEnabled: (value) => value == 'free' || premiumUnlocked,
                    ),
                  ],
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
            voiceMode: _xai.text.trim().isEmpty ? 'free' : current.voiceMode,
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
        'preferredProvider': settings.preferredProvider,
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

class _PracticeModeCard extends StatelessWidget {
  const _PracticeModeCard({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

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
            title,
            style: TextStyle(
              color: AppColors.primaryText(context),
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: AppColors.secondaryText(context),
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.options,
    required this.selected,
    required this.onChanged,
    this.isEnabled,
  });

  final List<(String, String)> options;
  final String selected;
  final ValueChanged<String> onChanged;
  final bool Function(String value)? isEnabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          Expanded(
            child: _ChoicePill(
              label: options[i].$2,
              selected: selected == options[i].$1,
              enabled: isEnabled?.call(options[i].$1) ?? true,
              onTap: () => onChanged(options[i].$1),
            ),
          ),
          if (i != options.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accentPurple : AppColors.softSurface(context),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 48,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  selected ? AppColors.accentPurple : AppColors.line(context),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!enabled) ...[
                Icon(
                  Icons.lock_rounded,
                  size: 14,
                  color: AppColors.secondaryText(context),
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : enabled
                            ? AppColors.primaryText(context)
                            : AppColors.secondaryText(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UsageCard extends StatelessWidget {
  const _UsageCard({
    required this.usage,
    required this.settings,
  });

  final ApiUsage usage;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final selectedProviderId = _resolveUsageProviderId(settings, usage);
    final provider = selectedProviderId == 'auto'
        ? null
        : ApiProviders.byId(selectedProviderId);
    final summary = selectedProviderId == 'auto'
        ? usage.totalSummary
        : usage.summaryForProvider(selectedProviderId);
    final practiceMinutesLeft = selectedProviderId == 'groq'
        ? usage.estimatedGroqPracticeMinutesLeft
        : null;
    final providerLabel = provider?.name ?? 'Auto router';
    final helperLabel = _helperLabel(
      selectedProviderId: selectedProviderId,
      usage: usage,
      settings: settings,
    );

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
              Expanded(
                child: Text(
                  provider?.usageTitle ?? 'Router usage',
                  style: TextStyle(
                    color: AppColors.primaryText(context),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.softSurface(context),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        providerLabel,
                        style: TextStyle(
                          color: AppColors.primaryText(context),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        helperLabel,
                        style: TextStyle(
                          color: AppColors.secondaryText(context),
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(
                      AppColors.isDark(context) ? 0.06 : 0.68,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    selectedProviderId == 'auto' ? 'Dynamic' : 'Active',
                    style: const TextStyle(
                      color: AppColors.accentPurple,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _UsageLine(
            label: 'Requests',
            value: summary.requests.toString(),
            progress: _requestProgress(selectedProviderId, summary.requests),
          ),
          const SizedBox(height: 12),
          _UsageLine(
            label: 'Chat tokens',
            value: _formatTokens(summary.tokens),
            progress: _tokenProgress(selectedProviderId, summary.tokens),
          ),
          if ((provider?.hasAudioTracking ?? false) ||
              summary.audioSeconds > 0) ...[
            const SizedBox(height: 12),
            _UsageLine(
              label: 'Audio',
              value: _formatAudio(summary.audioSeconds),
              progress:
                  _audioProgress(selectedProviderId, summary.audioSeconds),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.softSurface(context),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider?.billingLabel ?? 'Mixed usage',
                  style: TextStyle(
                    color: AppColors.primaryText(context),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  provider?.usageSummary ??
                      'This combines local usage tracked across the providers you have configured.',
                  style: TextStyle(
                    color: AppColors.secondaryText(context),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (selectedProviderId == 'gemini') ...[
            const SizedBox(height: 10),
            Text(
              'Remaining Gemini credits are managed in Google AI Studio and are not exposed directly to this app.',
              style: TextStyle(
                color: AppColors.secondaryText(context),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (practiceMinutesLeft != null)
            Text(
              '~$practiceMinutesLeft min practice left today',
              style: const TextStyle(
                color: AppColors.accentPurple,
                fontWeight: FontWeight.w900,
              ),
            ),
        ],
      ),
    );
  }

  String _resolveUsageProviderId(AppSettings settings, ApiUsage usage) {
    final activeProviders = usage.activeProviderIds;
    if (activeProviders.length > 1) {
      return 'auto';
    }
    if (activeProviders.length == 1) {
      return activeProviders.first;
    }
    if (!settings.isAutoProvider &&
        _hasKeyForProvider(settings.preferredProvider)) {
      return settings.preferredProvider;
    }
    for (final providerId in const [
      'groq',
      'gemini',
      'cerebras',
      'sambanova',
      'openrouter',
    ]) {
      if (_hasKeyForProvider(providerId)) {
        return providerId;
      }
    }
    return 'groq';
  }

  bool _hasKeyForProvider(String providerId) {
    return switch (providerId) {
      'groq' => settings.hasGroqKey,
      'gemini' => settings.geminiApiKey.trim().isNotEmpty,
      'cerebras' => settings.cerebrasApiKey.trim().isNotEmpty,
      'sambanova' => settings.sambanovaApiKey.trim().isNotEmpty,
      'openrouter' => settings.openRouterApiKey.trim().isNotEmpty,
      _ => false,
    };
  }

  String _helperLabel({
    required String selectedProviderId,
    required ApiUsage usage,
    required AppSettings settings,
  }) {
    final activeProviders = usage.activeProviderIds;
    if (activeProviders.length > 1) {
      return 'Showing combined usage because the router used multiple providers today.';
    }
    if (activeProviders.length == 1) {
      return 'Showing today\'s live usage from the provider the app actually used.';
    }
    if (!settings.hasAnyLlmKey) {
      return 'Add an API key and this card will automatically track the provider you use.';
    }
    if (selectedProviderId == 'groq' && settings.hasGroqKey) {
      return 'Ready to track Groq first, including Whisper audio and chat usage.';
    }
    return 'Ready to track the provider you start using first.';
  }

  String _formatTokens(int tokens) {
    if (tokens >= 1000) return '${(tokens / 1000).toStringAsFixed(1)}k';
    return tokens.toString();
  }

  String _formatAudio(int audioSeconds) {
    final minutes = (audioSeconds / 60).floor();
    return '$minutes min';
  }

  double _requestProgress(String providerId, int requests) {
    return switch (providerId) {
      'gemini' => requests / 60,
      'auto' => requests / 40,
      _ => requests / 30,
    };
  }

  double _tokenProgress(String providerId, int tokens) {
    return switch (providerId) {
      'groq' => tokens / 100000,
      'gemini' => tokens / 50000,
      _ => tokens / 50000,
    };
  }

  double _audioProgress(String providerId, int audioSeconds) {
    return switch (providerId) {
      'groq' => audioSeconds / 28800,
      _ => audioSeconds / 3600,
    };
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
    this.helper,
    this.onTest,
    this.onChanged,
    this.status,
    this.validating = false,
  });

  final TextEditingController controller;
  final String label;
  final bool required;
  final String? helper;
  final VoidCallback? onTest;
  final ValueChanged<String>? onChanged;
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
            onChanged: onChanged,
            decoration: InputDecoration(
              labelText: required ? '$label (required)' : label,
              helperText: helper,
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
