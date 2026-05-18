import 'package:flutter/material.dart';

class ApiProviderInfo {
  const ApiProviderInfo({
    required this.id,
    required this.name,
    required this.url,
    required this.kind,
    required this.description,
    required this.icon,
    required this.usageTitle,
    required this.usageSummary,
    required this.billingLabel,
    this.hasAudioTracking = false,
    this.isRequired = false,
  });

  final String id;
  final String name;
  final String url;
  final String kind;
  final String description;
  final IconData icon;
  final String usageTitle;
  final String usageSummary;
  final String billingLabel;
  final bool hasAudioTracking;
  final bool isRequired;
}

class ApiProviders {
  const ApiProviders._();

  static const groq = ApiProviderInfo(
    id: 'groq',
    name: 'Groq',
    url: 'https://console.groq.com/keys',
    kind: 'Free',
    description:
        'Required for Whisper transcription and the primary free chat model.',
    icon: Icons.key_rounded,
    usageTitle: 'Groq usage',
    usageSummary: 'Tracks local Whisper audio time and chat token usage.',
    billingLabel: 'Free quota',
    hasAudioTracking: true,
    isRequired: true,
  );

  static const cerebras = ApiProviderInfo(
    id: 'cerebras',
    name: 'Cerebras',
    url: 'https://cloud.cerebras.ai/platform',
    kind: 'Free',
    description: 'Recommended fallback for extra free LLM capacity.',
    icon: Icons.bolt_rounded,
    usageTitle: 'Cerebras usage',
    usageSummary: 'Tracks local request count and estimated chat tokens.',
    billingLabel: 'Free capacity',
  );

  static const sambanova = ApiProviderInfo(
    id: 'sambanova',
    name: 'SambaNova',
    url: 'https://cloud.sambanova.ai/',
    kind: 'Free',
    description: 'Optional fallback provider for more free capacity.',
    icon: Icons.cloud_queue_rounded,
    usageTitle: 'SambaNova usage',
    usageSummary: 'Tracks local request count and estimated chat tokens.',
    billingLabel: 'Free capacity',
  );

  static const gemini = ApiProviderInfo(
    id: 'gemini',
    name: 'Gemini',
    url: 'https://aistudio.google.com/app/apikey',
    kind: 'Free',
    description: 'Recommended reliable fallback from Google AI Studio.',
    icon: Icons.auto_awesome_rounded,
    usageTitle: 'Gemini usage',
    usageSummary:
        'Tracks local chat usage. Gemini quota and credits stay in Google AI Studio.',
    billingLabel: 'Credits / quota',
  );

  static const openRouter = ApiProviderInfo(
    id: 'openrouter',
    name: 'OpenRouter',
    url: 'https://openrouter.ai/keys',
    kind: 'Free',
    description: 'Optional router for free community models.',
    icon: Icons.route_rounded,
    usageTitle: 'OpenRouter usage',
    usageSummary:
        'Tracks local chat usage. Wallet balance stays in OpenRouter.',
    billingLabel: 'Credits / wallet',
  );

  static const xai = ApiProviderInfo(
    id: 'xai',
    name: 'xAI',
    url: 'https://console.x.ai/',
    kind: 'Premium',
    description:
        'Optional premium key for higher quality voice features later.',
    icon: Icons.graphic_eq_rounded,
    usageTitle: 'xAI unlock',
    usageSummary:
        'Unlocks Premium mode in the UI. Runtime voice switching is not live yet.',
    billingLabel: 'Premium key',
  );

  static const free = [groq, cerebras, sambanova, gemini, openRouter];
  static const premium = [xai];
  static const all = [groq, cerebras, sambanova, gemini, openRouter, xai];

  static ApiProviderInfo byId(String id) {
    return all.firstWhere(
      (provider) => provider.id == id,
      orElse: () => groq,
    );
  }
}
