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
  final _deepSeek = TextEditingController();
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
    _deepSeek.dispose();
    _xai.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final usage = ref.watch(usageProvider);
    final liveVoiceUnlocked =
        _gemini.text.trim().isNotEmpty || settings.hasGeminiKey;
    final selectedVoiceMode =
        liveVoiceUnlocked ? settings.voiceMode : 'standard';
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
                const SizedBox(height: 14),
                _AppearanceCard(
                  isDarkMode: settings.isDarkMode,
                  onChanged: (value) {
                    ref.read(settingsProvider.notifier).update(
                          (current) => current.copyWith(isDarkMode: value),
                        );
                  },
                ),
                const SizedBox(height: 12),
                _UsageCard(
                  usage: usage,
                  settings: settings,
                ),
                const SizedBox(height: 12),
                _SettingsSectionCard(
                  icon: Icons.key_rounded,
                  title: 'API connections',
                  subtitle: _apiSummary(settings),
                  trailingText: '${_connectedApiCount(settings)} saved',
                  children: [
                    if (!settings.isLoaded) ...[
                      const LinearProgressIndicator(minHeight: 3),
                      const SizedBox(height: 14),
                    ],
                    const ApiKeyGuide(),
                    const SizedBox(height: 14),
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
                      controller: _deepSeek,
                      label: 'DeepSeek API key',
                      status: _validation['deepseek'],
                      validating: _validating.contains('deepseek'),
                      onTest: () => _testKey('deepseek', _deepSeek.text),
                    ),
                    _KeyField(
                      controller: _xai,
                      label: 'xAI API key',
                      helper:
                          'Optional future premium voice key for richer AI voice options.',
                      onChanged: (value) {
                        setState(() {});
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SettingsSectionCard(
                  icon: Icons.tune_rounded,
                  title: 'Practice setup',
                  subtitle:
                      '${settings.difficultyLabel} level, ${settings.groqChatModeLabel.toLowerCase()} Groq, ${settings.dailyGoalMinutes} min goal',
                  children: [
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
                                  (current) =>
                                      current.copyWith(difficulty: value),
                                );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _PracticeModeCard(
                      title: 'Groq response mode',
                      subtitle: settings.groqChatModeSummary,
                      children: [
                        _ChoiceRow(
                          options: const [
                            ('fast', 'Fast'),
                            ('smart', 'Smart'),
                          ],
                          selected: settings.groqChatMode,
                          onChanged: (value) {
                            ref.read(settingsProvider.notifier).update(
                                  (current) =>
                                      current.copyWith(groqChatMode: value),
                                );
                          },
                        ),
                        _MiniNote(
                          text: settings.isGroqSmartMode
                              ? 'Uses Llama 4 Maverick, then Scout if needed.'
                              : 'Uses Llama 4 Scout for faster daily practice.',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _PracticeModeCard(
                      title: 'DeepSeek response mode',
                      subtitle: settings.deepSeekChatModeSummary,
                      children: [
                        _ChoiceRow(
                          options: const [
                            ('flash', 'Flash'),
                            ('pro', 'Pro'),
                          ],
                          selected: settings.deepSeekChatMode,
                          onChanged: (value) {
                            ref.read(settingsProvider.notifier).update(
                                  (current) =>
                                      current.copyWith(deepSeekChatMode: value),
                                );
                          },
                        ),
                        _MiniNote(
                          text: settings.isDeepSeekProMode
                              ? 'Uses DeepSeek V4 Pro.'
                              : 'Uses DeepSeek V4 Flash.',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _PracticeModeCard(
                      title: 'Voice engine',
                      subtitle: liveVoiceUnlocked
                          ? 'Live Voice is ready for a smoother AI speaking flow. Standard voice stays available.'
                          : 'Standard voice uses transcription, the router, and device TTS. Add a Live Voice key for the smoother AI speaking flow.',
                      children: [
                        _ChoiceRow(
                          options: const [
                            ('standard', 'Standard'),
                            ('live', 'Live Voice'),
                          ],
                          selected: selectedVoiceMode,
                          onChanged: (value) {
                            if (value == 'live' && !liveVoiceUnlocked) return;
                            ref.read(settingsProvider.notifier).update(
                                  (current) =>
                                      current.copyWith(voiceMode: value),
                                );
                          },
                          isEnabled: (value) =>
                              value == 'standard' || liveVoiceUnlocked,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SliderSetting(
                      label:
                          'Speaking speed ${settings.speakingSpeed.toStringAsFixed(1)}x',
                      value: settings.speakingSpeed,
                      min: 0.5,
                      max: 2.0,
                      divisions: 15,
                      onChanged: (value) {
                        ref.read(settingsProvider.notifier).update(
                              (current) =>
                                  current.copyWith(speakingSpeed: value),
                            );
                      },
                    ),
                    const SizedBox(height: 12),
                    _SliderSetting(
                      label: 'Daily goal ${settings.dailyGoalMinutes} min',
                      value: settings.dailyGoalMinutes.toDouble().clamp(5, 60),
                      min: 5,
                      max: 60,
                      divisions: 11,
                      onChanged: (value) {
                        ref.read(settingsProvider.notifier).update(
                              (current) => current.copyWith(
                                dailyGoalMinutes: value.round(),
                              ),
                            );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
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
    _deepSeek.text = settings.deepSeekApiKey;
    _xai.text = settings.xaiApiKey;
    _hydrated = true;
  }

  int _connectedApiCount(AppSettings settings) {
    return [
      settings.groqApiKey,
      settings.cerebrasApiKey,
      settings.sambanovaApiKey,
      settings.geminiApiKey,
      settings.openRouterApiKey,
      settings.deepSeekApiKey,
      settings.xaiApiKey,
    ].where((key) => key.trim().isNotEmpty).length;
  }

  String _apiSummary(AppSettings settings) {
    final count = _connectedApiCount(settings);
    if (count == 0) return 'Add keys and provider links only when needed';
    if (count == 1) return 'One provider is ready for practice';
    return '$count providers are ready for practice';
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
            deepSeekApiKey: _deepSeek.text,
            xaiApiKey: _xai.text,
            voiceMode:
                _gemini.text.trim().isEmpty ? 'standard' : current.voiceMode,
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
        'groqChatMode': settings.groqChatMode,
        'deepSeekChatMode': settings.deepSeekChatMode,
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

class _SettingsSectionCard extends StatelessWidget {
  const _SettingsSectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
    this.trailingText,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailingText;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line(context)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.softSurface(context),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.accentPurple, size: 20),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.primaryText(context),
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              if (trailingText != null) ...[
                const SizedBox(width: 8),
                _TinyStatusPill(text: trailingText!),
              ],
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.secondaryText(context),
                fontSize: 12,
                height: 1.25,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          children: children,
        ),
      ),
    );
  }
}

class _TinyStatusPill extends StatelessWidget {
  const _TinyStatusPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
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

class _MiniNote extends StatelessWidget {
  const _MiniNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: AppColors.secondaryText(context),
        fontSize: 12,
        height: 1.35,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _SliderSetting extends StatelessWidget {
  const _SliderSetting({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.primaryText(context),
            fontWeight: FontWeight.w900,
          ),
        ),
        Slider(
          min: min,
          max: max,
          divisions: divisions,
          value: value,
          onChanged: onChanged,
        ),
      ],
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
        : selectedProviderId == 'none'
            ? null
            : ApiProviders.byId(selectedProviderId);
    final summary = selectedProviderId == 'auto'
        ? usage.totalSummary
        : selectedProviderId == 'none'
            ? const ApiUsageSummary(
                providerId: 'none',
                requests: 0,
                promptTokens: 0,
                completionTokens: 0,
                totalTokens: 0,
                estimatedTokens: 0,
                audioSeconds: 0,
              )
            : usage.summaryForProvider(selectedProviderId);
    final practiceMinutesLeft = selectedProviderId == 'groq'
        ? usage.estimatedGroqPracticeMinutesLeft
        : null;
    final providerLabel = switch (selectedProviderId) {
      'auto' => 'Auto router',
      'none' => 'No API connected',
      _ => provider?.name ?? 'Provider',
    };
    final helperLabel = _helperLabel(
      selectedProviderId: selectedProviderId,
      usage: usage,
      settings: settings,
    );
    final status = _providerStatus(
      selectedProviderId: selectedProviderId,
      usage: usage,
      settings: settings,
    );
    final statusColor = _statusColor(context, status);

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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.softSurface(context),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.speed_rounded,
                  color: AppColors.accentPurple,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Usage today',
                      style: TextStyle(
                        color: AppColors.primaryText(context),
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      providerLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.secondaryText(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(
                    AppColors.isDark(context) ? 0.18 : 0.12,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            helperLabel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.secondaryText(context),
              fontSize: 12,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _UsageMetricChip(
                label: 'Requests',
                value: summary.requests.toString(),
                icon: Icons.call_made_rounded,
              ),
              _UsageMetricChip(
                label: _tokenLabel(summary),
                value: _formatTokens(summary.displayTokens),
                icon: Icons.data_object_rounded,
              ),
              if ((provider?.hasAudioTracking ?? false) ||
                  summary.audioSeconds > 0)
                _UsageMetricChip(
                  label: 'Audio',
                  value: _formatAudio(summary.audioSeconds),
                  icon: Icons.mic_rounded,
                ),
            ],
          ),
          if (summary.hasExactTokens) ...[
            const SizedBox(height: 10),
            Text(
              'Prompt ${_formatTokens(summary.promptTokens)}  |  Reply ${_formatTokens(summary.completionTokens)}',
              style: TextStyle(
                color: AppColors.secondaryText(context),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (selectedProviderId != 'none' && summary.displayTokens > 0) ...[
            const SizedBox(height: 10),
            Text(
              _tokenSourceNote(summary),
              style: TextStyle(
                color: AppColors.secondaryText(context),
                fontSize: 11,
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
                fontSize: 13,
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
      'deepseek',
    ]) {
      if (_hasKeyForProvider(providerId)) {
        return providerId;
      }
    }
    return 'none';
  }

  bool _hasKeyForProvider(String providerId) {
    return switch (providerId) {
      'groq' => settings.hasGroqKey,
      'gemini' => settings.geminiApiKey.trim().isNotEmpty,
      'cerebras' => settings.cerebrasApiKey.trim().isNotEmpty,
      'sambanova' => settings.sambanovaApiKey.trim().isNotEmpty,
      'openrouter' => settings.openRouterApiKey.trim().isNotEmpty,
      'deepseek' => settings.deepSeekApiKey.trim().isNotEmpty,
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
    if (selectedProviderId == 'none') {
      return 'No API key saved yet. Add a provider below to activate usage tracking.';
    }
    if (!settings.hasAnyLlmKey) {
      return 'Add an API key and this card will automatically track the provider you use.';
    }
    if (selectedProviderId == 'groq' && settings.hasGroqKey) {
      return 'Ready to track Groq first, including Whisper audio and chat usage.';
    }
    return 'Ready to track the provider you start using first.';
  }

  String _providerStatus({
    required String selectedProviderId,
    required ApiUsage usage,
    required AppSettings settings,
  }) {
    if (selectedProviderId == 'auto') {
      return 'Dynamic';
    }
    if (selectedProviderId == 'none' || !settings.hasAnyLlmKey) {
      return 'Inactive';
    }
    if (usage.activeProviderIds.contains(selectedProviderId)) {
      return 'Active';
    }
    if (_hasKeyForProvider(selectedProviderId)) {
      return 'Ready';
    }
    return 'Inactive';
  }

  Color _statusColor(BuildContext context, String status) {
    return switch (status) {
      'Active' => AppColors.accentGreen,
      'Ready' => AppColors.accentPurple,
      'Dynamic' => AppColors.accentPurple,
      _ => AppColors.secondaryText(context),
    };
  }

  String _formatTokens(int tokens) {
    if (tokens >= 1000) return '${(tokens / 1000).toStringAsFixed(1)}k';
    return tokens.toString();
  }

  String _tokenLabel(ApiUsageSummary summary) {
    if (summary.isMixedTokenSource) return 'Mixed chat tokens';
    if (summary.hasExactTokens) return 'Chat tokens';
    return 'Est. chat tokens';
  }

  String _tokenSourceNote(ApiUsageSummary summary) {
    if (summary.isMixedTokenSource) {
      return 'Exact provider token usage is shown where available, with estimates only for providers that do not report token counts.';
    }
    if (summary.hasExactTokens) {
      return 'These token counts come directly from provider usage metadata.';
    }
    return 'These token counts are estimated from conversation length because this provider did not return usage metadata.';
  }

  String _formatAudio(int audioSeconds) {
    if (audioSeconds < 60) return '$audioSeconds sec';
    final minutes = (audioSeconds / 60).floor();
    return '$minutes min';
  }
}

class _UsageMetricChip extends StatelessWidget {
  const _UsageMetricChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 105,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.softSurface(context),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: AppColors.accentPurple,
                size: 17,
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: AppColors.primaryText(context),
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.secondaryText(context),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
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
