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
    this.preferredProvider = 'auto',
    this.voiceName = '',
    this.speakingSpeed = 1.0,
    this.accent = 'US',
    this.isDarkMode = false,
    this.hasCompletedOnboarding = false,
    this.dailyGoalMinutes = 10,
    this.isLoaded = false,
  });

  final String groqApiKey;
  final String cerebrasApiKey;
  final String sambanovaApiKey;
  final String geminiApiKey;
  final String openRouterApiKey;
  final String xaiApiKey;
  final String difficulty;
  final String voiceMode;
  final String preferredProvider;
  final String voiceName;
  final double speakingSpeed;
  final String accent;
  final bool isDarkMode;
  final bool hasCompletedOnboarding;
  final int dailyGoalMinutes;
  final bool isLoaded;

  bool get hasGroqKey => groqApiKey.trim().isNotEmpty;
  bool get hasXaiKey => xaiApiKey.trim().isNotEmpty;
  bool get hasAnyLlmKey =>
      hasGroqKey ||
      cerebrasApiKey.trim().isNotEmpty ||
      sambanovaApiKey.trim().isNotEmpty ||
      geminiApiKey.trim().isNotEmpty ||
      openRouterApiKey.trim().isNotEmpty;

  String get difficultyLabel => switch (difficulty) {
        'advanced' => 'Advanced',
        'intermediate' => 'Intermediate',
        _ => 'Beginner',
      };

  bool get isPremiumMode => voiceMode == 'premium';
  bool get premiumUnlocked => hasXaiKey;
  bool get isAutoProvider => preferredProvider == 'auto';

  String get difficultySummary => switch (difficulty) {
        'advanced' =>
          'Faster replies, richer vocabulary, and more natural complexity.',
        'intermediate' =>
          'Balanced vocabulary, moderate pace, and guided conversation.',
        _ => 'Simpler words, shorter replies, and gentler corrections.',
      };

  AppSettings copyWith({
    String? groqApiKey,
    String? cerebrasApiKey,
    String? sambanovaApiKey,
    String? geminiApiKey,
    String? openRouterApiKey,
    String? xaiApiKey,
    String? difficulty,
    String? voiceMode,
    String? preferredProvider,
    String? voiceName,
    double? speakingSpeed,
    String? accent,
    bool? isDarkMode,
    bool? hasCompletedOnboarding,
    int? dailyGoalMinutes,
    bool? isLoaded,
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
      preferredProvider: preferredProvider ?? this.preferredProvider,
      voiceName: voiceName ?? this.voiceName,
      speakingSpeed: speakingSpeed ?? this.speakingSpeed,
      accent: accent ?? this.accent,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }

  Map<String, dynamic> toJson() => {
        'difficulty': difficulty,
        'voiceMode': voiceMode,
        'preferredProvider': preferredProvider,
        'voiceName': voiceName,
        'speakingSpeed': speakingSpeed,
        'accent': accent,
        'isDarkMode': isDarkMode,
        'hasCompletedOnboarding': hasCompletedOnboarding,
        'dailyGoalMinutes': dailyGoalMinutes,
      };

  factory AppSettings.fromJson(Map<dynamic, dynamic> json) {
    return AppSettings(
      difficulty: json['difficulty']?.toString() ?? 'beginner',
      voiceMode: json['voiceMode']?.toString() ?? 'free',
      preferredProvider: json['preferredProvider']?.toString() ?? 'auto',
      voiceName: json['voiceName']?.toString() ?? '',
      speakingSpeed: (json['speakingSpeed'] as num?)?.toDouble() ?? 1.0,
      accent: json['accent']?.toString() ?? 'US',
      isDarkMode: json['isDarkMode'] == true,
      hasCompletedOnboarding: json['hasCompletedOnboarding'] == true,
      dailyGoalMinutes: (json['dailyGoalMinutes'] as num?)?.toInt() ?? 10,
      isLoaded: true,
    );
  }
}
