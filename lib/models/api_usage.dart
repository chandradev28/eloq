class ApiUsageEntry {
  const ApiUsageEntry({
    this.requests = 0,
    this.tokens = 0,
    this.audioSeconds = 0,
  });

  final int requests;
  final int tokens;
  final int audioSeconds;

  ApiUsageEntry copyWith({
    int? requests,
    int? tokens,
    int? audioSeconds,
  }) {
    return ApiUsageEntry(
      requests: requests ?? this.requests,
      tokens: tokens ?? this.tokens,
      audioSeconds: audioSeconds ?? this.audioSeconds,
    );
  }

  Map<String, dynamic> toJson() => {
        'requests': requests,
        'tokens': tokens,
        'audioSeconds': audioSeconds,
      };

  factory ApiUsageEntry.fromJson(Map<dynamic, dynamic> json) {
    return ApiUsageEntry(
      requests: (json['requests'] as num?)?.toInt() ?? 0,
      tokens: (json['tokens'] as num?)?.toInt() ?? 0,
      audioSeconds: (json['audioSeconds'] as num?)?.toInt() ?? 0,
    );
  }
}

class ApiUsage {
  const ApiUsage({
    required this.dateKey,
    this.entries = const {},
  });

  final String dateKey;
  final Map<String, ApiUsageEntry> entries;

  static String todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  ApiUsage normalizedForToday() {
    final today = todayKey();
    if (dateKey == today) return this;
    return ApiUsage(dateKey: today);
  }

  ApiUsageEntry entry(String key) => entries[key] ?? const ApiUsageEntry();

  ApiUsageSummary summaryForProvider(String providerId) {
    var requests = 0;
    var tokens = 0;
    var audioSeconds = 0;
    for (final item in entries.entries) {
      if (!item.key.startsWith('$providerId:')) continue;
      requests += item.value.requests;
      tokens += item.value.tokens;
      audioSeconds += item.value.audioSeconds;
    }
    return ApiUsageSummary(
      providerId: providerId,
      requests: requests,
      tokens: tokens,
      audioSeconds: audioSeconds,
    );
  }

  ApiUsageSummary get totalSummary {
    var requests = 0;
    var tokens = 0;
    var audioSeconds = 0;
    for (final item in entries.values) {
      requests += item.requests;
      tokens += item.tokens;
      audioSeconds += item.audioSeconds;
    }
    return ApiUsageSummary(
      providerId: 'auto',
      requests: requests,
      tokens: tokens,
      audioSeconds: audioSeconds,
    );
  }

  List<String> get activeProviderIds {
    final providers = <String>{};
    for (final item in entries.entries) {
      if (item.value.requests == 0 &&
          item.value.tokens == 0 &&
          item.value.audioSeconds == 0) {
        continue;
      }
      final provider = item.key.split(':').first.trim();
      if (provider.isNotEmpty) {
        providers.add(provider);
      }
    }
    return providers.toList()..sort();
  }

  ApiUsage increment(
    String key, {
    int requests = 0,
    int tokens = 0,
    int audioSeconds = 0,
  }) {
    final current = entry(key);
    return ApiUsage(
      dateKey: dateKey,
      entries: {
        ...entries,
        key: current.copyWith(
          requests: current.requests + requests,
          tokens: current.tokens + tokens,
          audioSeconds: current.audioSeconds + audioSeconds,
        ),
      },
    );
  }

  int get groqChatRequests => entry('groq:llama-3.3-70b-versatile').requests;
  int get groqChatTokens => entry('groq:llama-3.3-70b-versatile').tokens;
  int get groqAudioSeconds => entry('groq:whisper-large-v3-turbo').audioSeconds;
  int get groqWhisperRequests => entry('groq:whisper-large-v3-turbo').requests;

  int get estimatedGroqPracticeMinutesLeft {
    const dailyAudioSeconds = 28800;
    const dailyTokens = 100000;
    final audioMinutesLeft =
        ((dailyAudioSeconds - groqAudioSeconds).clamp(0, dailyAudioSeconds) /
                60)
            .floor();
    final tokenMinutesLeft =
        ((dailyTokens - groqChatTokens).clamp(0, dailyTokens) / 900).floor();
    return audioMinutesLeft < tokenMinutesLeft
        ? audioMinutesLeft
        : tokenMinutesLeft;
  }

  Map<String, dynamic> toJson() => {
        'dateKey': dateKey,
        'entries': entries.map((key, value) => MapEntry(key, value.toJson())),
      };

  factory ApiUsage.fromJson(Map<dynamic, dynamic> json) {
    final rawEntries = json['entries'] as Map?;
    return ApiUsage(
      dateKey: json['dateKey']?.toString() ?? todayKey(),
      entries: rawEntries == null
          ? const {}
          : rawEntries.map(
              (key, value) => MapEntry(
                key.toString(),
                value is Map
                    ? ApiUsageEntry.fromJson(value)
                    : const ApiUsageEntry(),
              ),
            ),
    ).normalizedForToday();
  }
}

class ApiUsageSummary {
  const ApiUsageSummary({
    required this.providerId,
    required this.requests,
    required this.tokens,
    required this.audioSeconds,
  });

  final String providerId;
  final int requests;
  final int tokens;
  final int audioSeconds;

  int get audioMinutes => (audioSeconds / 60).floor();
}
