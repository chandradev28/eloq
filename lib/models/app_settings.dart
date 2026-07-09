class AppSettings {
  const AppSettings({
    this.groqApiKey = '',
    this.geminiApiKey = '',
    this.openRouterApiKey = '',
    this.deepSeekApiKey = '',
    this.xaiApiKey = '',
    this.difficulty = 'beginner',
    this.voiceMode = 'standard',
    this.groqChatMode = 'fast',
    this.deepSeekChatMode = 'flash',
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
  final String geminiApiKey;
  final String openRouterApiKey;
  final String deepSeekApiKey;
  final String xaiApiKey;
  final String difficulty;
  final String voiceMode;
  final String groqChatMode;
  final String deepSeekChatMode;
  final String preferredProvider;
  final String voiceName;
  final double speakingSpeed;
  final String accent;
  final bool isDarkMode;
  final bool hasCompletedOnboarding;
  final int dailyGoalMinutes;
  final bool isLoaded;

  bool get hasGroqKey => groqApiKey.trim().isNotEmpty;
  bool get hasGeminiKey => geminiApiKey.trim().isNotEmpty;
  bool get hasDeepSeekKey => deepSeekApiKey.trim().isNotEmpty;
  bool get hasXaiKey => xaiApiKey.trim().isNotEmpty;
  bool get hasAnyLlmKey =>
      hasGroqKey ||
      geminiApiKey.trim().isNotEmpty ||
      hasDeepSeekKey ||
      openRouterApiKey.trim().isNotEmpty;

  String get difficultyLabel => switch (difficulty) {
        'advanced' => 'Advanced',
        'intermediate' => 'Intermediate',
        _ => 'Beginner',
      };

  bool get isLiveVoiceMode => voiceMode == 'live';
  bool get liveVoiceUnlocked => hasGeminiKey;
  bool get isAutoProvider => preferredProvider == 'auto';
  bool get isGroqSmartMode => groqChatMode == 'smart';

  String get groqChatModel => switch (groqChatMode) {
        'smart' => 'meta-llama/llama-4-maverick-17b-128e-instruct',
        _ => 'meta-llama/llama-4-scout-17b-16e-instruct',
      };

  String get groqChatModeLabel => switch (groqChatMode) {
        'smart' => 'Smart',
        _ => 'Fast',
      };

  String get groqChatModeSummary => switch (groqChatMode) {
        'smart' =>
          'Llama 4 Maverick gives richer answers and stronger reasoning for deeper practice.',
        _ =>
          'Llama 4 Scout keeps daily practice quick, natural, and responsive.',
      };

  bool get isDeepSeekProMode => deepSeekChatMode == 'pro';

  String get deepSeekChatModel => switch (deepSeekChatMode) {
        'pro' => 'deepseek-v4-pro',
        _ => 'deepseek-v4-flash',
      };

  String get deepSeekChatModeSummary => switch (deepSeekChatMode) {
        'pro' =>
          'Pro is for deeper answers, stronger reasoning, and richer corrections.',
        _ =>
          'Flash is the faster, lower-cost DeepSeek option for daily practice.',
      };

  String get difficultySummary => switch (difficulty) {
        'advanced' =>
          'Faster replies, richer vocabulary, and more natural complexity.',
        'intermediate' =>
          'Balanced vocabulary, moderate pace, and guided conversation.',
        _ => 'Simpler words, shorter replies, and gentler corrections.',
      };

  AppSettings copyWith({
    String? groqApiKey,
    String? geminiApiKey,
    String? openRouterApiKey,
    String? deepSeekApiKey,
    String? xaiApiKey,
    String? difficulty,
    String? voiceMode,
    String? groqChatMode,
    String? deepSeekChatMode,
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
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      openRouterApiKey: openRouterApiKey ?? this.openRouterApiKey,
      deepSeekApiKey: deepSeekApiKey ?? this.deepSeekApiKey,
      xaiApiKey: xaiApiKey ?? this.xaiApiKey,
      difficulty: difficulty ?? this.difficulty,
      voiceMode: voiceMode ?? this.voiceMode,
      groqChatMode: groqChatMode ?? this.groqChatMode,
      deepSeekChatMode: deepSeekChatMode ?? this.deepSeekChatMode,
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
        'groqChatMode': groqChatMode,
        'deepSeekChatMode': deepSeekChatMode,
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
      voiceMode: switch (json['voiceMode']?.toString()) {
        'premium' => 'live',
        'free' => 'standard',
        'live' => 'live',
        _ => 'standard',
      },
      groqChatMode: switch (json['groqChatMode']?.toString()) {
        'smart' => 'smart',
        'maverick' => 'smart',
        'scout' => 'fast',
        _ => 'fast',
      },
      deepSeekChatMode: switch (json['deepSeekChatMode']?.toString()) {
        'pro' => 'pro',
        _ => 'flash',
      },
      preferredProvider: switch (json['preferredProvider']?.toString()) {
        'groq' => 'groq',
        'gemini' => 'gemini',
        'openrouter' => 'openrouter',
        'deepseek' => 'deepseek',
        _ => 'auto',
      },
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
