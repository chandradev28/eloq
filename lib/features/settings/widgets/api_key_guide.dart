import 'package:flutter/material.dart';

import '../../../core/constants/api_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/link_launcher.dart';

class ApiKeyGuide extends StatelessWidget {
  const ApiKeyGuide({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Where to get API keys',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Start with Groq. Add more free providers only when you want extra daily capacity.',
              style: TextStyle(color: AppColors.secondaryText(context)),
            ),
            const SizedBox(height: 14),
            const _ProviderGroup(
                title: 'Free providers', providers: ApiProviders.free),
            const SizedBox(height: 12),
            const _ProviderGroup(
                title: 'Premium unlock', providers: ApiProviders.premium),
          ],
        ),
      ),
    );
  }
}

class ProviderKeyButton extends StatelessWidget {
  const ProviderKeyButton({
    super.key,
    required this.provider,
    this.compact = false,
  });

  final ApiProviderInfo provider;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => openExternalLink(context, provider.url),
      icon: Icon(provider.icon, size: compact ? 16 : 18),
      label:
          Text(compact ? '${provider.name} key' : 'Get ${provider.name} key'),
      style: compact
          ? OutlinedButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            )
          : null,
    );
  }
}

class _ProviderGroup extends StatelessWidget {
  const _ProviderGroup({
    required this.title,
    required this.providers,
  });

  final String title;
  final List<ApiProviderInfo> providers;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.secondaryText(context),
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        for (final provider in providers) _ProviderRow(provider: provider),
      ],
    );
  }
}

class _ProviderRow extends StatelessWidget {
  const _ProviderRow({required this.provider});

  final ApiProviderInfo provider;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(provider.icon, color: AppColors.accentTeal, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    Text(
                      provider.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    _ProviderChip(
                      text: provider.isRequired ? 'Required' : provider.kind,
                      color: provider.kind == 'Premium'
                          ? AppColors.accentYellow
                          : AppColors.accentGreen,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  provider.description,
                  style: TextStyle(
                    color: AppColors.secondaryText(context),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Open ${provider.name}',
            onPressed: () => openExternalLink(context, provider.url),
            icon: const Icon(Icons.open_in_new_rounded),
          ),
        ],
      ),
    );
  }
}

class _ProviderChip extends StatelessWidget {
  const _ProviderChip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.36)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
