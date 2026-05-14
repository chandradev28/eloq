import 'package:flutter/material.dart';

class ApiProviderInfo {
  const ApiProviderInfo({
    required this.name,
    required this.url,
    required this.kind,
    required this.description,
    required this.icon,
    this.isRequired = false,
  });

  final String name;
  final String url;
  final String kind;
  final String description;
  final IconData icon;
  final bool isRequired;
}

class ApiProviders {
  const ApiProviders._();

  static const groq = ApiProviderInfo(
    name: 'Groq',
    url: 'https://console.groq.com/keys',
    kind: 'Free',
    description:
        'Required for Whisper transcription and the primary free chat model.',
    icon: Icons.key_rounded,
    isRequired: true,
  );

  static const cerebras = ApiProviderInfo(
    name: 'Cerebras',
    url: 'https://cloud.cerebras.ai/platform',
    kind: 'Free',
    description: 'Recommended fallback for extra free LLM capacity.',
    icon: Icons.bolt_rounded,
  );

  static const sambanova = ApiProviderInfo(
    name: 'SambaNova',
    url: 'https://cloud.sambanova.ai/',
    kind: 'Free',
    description: 'Optional fallback provider for more free capacity.',
    icon: Icons.cloud_queue_rounded,
  );

  static const gemini = ApiProviderInfo(
    name: 'Gemini',
    url: 'https://aistudio.google.com/app/apikey',
    kind: 'Free',
    description: 'Recommended reliable fallback from Google AI Studio.',
    icon: Icons.auto_awesome_rounded,
  );

  static const openRouter = ApiProviderInfo(
    name: 'OpenRouter',
    url: 'https://openrouter.ai/keys',
    kind: 'Free',
    description: 'Optional router for free community models.',
    icon: Icons.route_rounded,
  );

  static const xai = ApiProviderInfo(
    name: 'xAI',
    url: 'https://console.x.ai/',
    kind: 'Premium',
    description:
        'Optional premium key for higher quality voice features later.',
    icon: Icons.graphic_eq_rounded,
  );

  static const free = [groq, cerebras, sambanova, gemini, openRouter];
  static const premium = [xai];
  static const all = [groq, cerebras, sambanova, gemini, openRouter, xai];
}
