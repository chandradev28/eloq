class AppSettings {
  const AppSettings({
    this.groqApiKey = '',
    this.cerebrasApiKey = '',
    this.sambanovaApiKey = '',
    this.geminiApiKey = '',
    this.openRouterApiKey = '',
    this.xaiApiKey = '',
    this.difficulty = 'beginner',
    this.voiceMode = 'free',
    this.voiceName = '',
    this.speakingSpeed = 1.0,
    this.accent = 'US',
  });

  final String groqApiKey;
  final String cerebrasApiKey;
  final String sambanovaApiKey;
  final String geminiApiKey;
  final String openRouterApiKey;
  final String xaiApiKey;
  final String difficulty;
  final String voiceMode;
  final String voiceName;
  final double speakingSpeed;
  final String accent;

  bool get hasGroqKey => groqApiKey.trim().isNotEmpty;
  bool get hasAnyLlmKey =>
      hasGroqKey ||
      cerebrasApiKey.trim().isNotEmpty ||
      sambanovaApiKey.trim().isNotEmpty ||
      geminiApiKey.trim().isNotEmpty ||
      openRouterApiKey.trim().isNotEmpty;

  AppSettings copyWith({
    String? groqApiKey,
    String? cerebrasApiKey,
    String? sambanovaApiKey,
    String? geminiApiKey,
    String? openRouterApiKey,
    String? xaiApiKey,
    String? difficulty,
    String? voiceMode,
    String? voiceName,
    double? speakingSpeed,
    String? accent,
  }) {
    return AppSettings(
      groqApiKey: groqApiKey ?? this.groqApiKey,
      cerebrasApiKey: cerebrasApiKey ?? this.cerebrasApiKey,
      sambanovaApiKey: sambanovaApiKey ?? this.sambanovaApiKey,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      openRouterApiKey: openRouterApiKey ?? this.openRouterApiKey,
      xaiApiKey: xaiApiKey ?? this.xaiApiKey,
      difficulty: difficulty ?? this.difficulty,
      voiceMode: voiceMode ?? this.voiceMode,
      voiceName: voiceName ?? this.voiceName,
      speakingSpeed: speakingSpeed ?? this.speakingSpeed,
      accent: accent ?? this.accent,
    );
  }

  Map<String, dynamic> toJson() => {
        'difficulty': difficulty,
        'voiceMode': voiceMode,
        'voiceName': voiceName,
        'speakingSpeed': speakingSpeed,
        'accent': accent,
      };

  factory AppSettings.fromJson(Map<dynamic, dynamic> json) {
    return AppSettings(
      difficulty: json['difficulty']?.toString() ?? 'beginner',
      voiceMode: json['voiceMode']?.toString() ?? 'free',
      voiceName: json['voiceName']?.toString() ?? '',
      speakingSpeed: (json['speakingSpeed'] as num?)?.toDouble() ?? 1.0,
      accent: json['accent']?.toString() ?? 'US',
    );
  }
}
