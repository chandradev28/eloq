class ApiUsageEntry {
  const ApiUsageEntry({
    this.requests = 0,
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.totalTokens = 0,
    this.estimatedTokens = 0,
    this.audioSeconds = 0,
  });

  final int requests;
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final int estimatedTokens;
  final int audioSeconds;

  ApiUsageEntry copyWith({
    int? requests,
    int? promptTokens,
    int? completionTokens,
    int? totalTokens,
    int? estimatedTokens,
    int? audioSeconds,
  }) {
    return ApiUsageEntry(
      requests: requests ?? this.requests,
      promptTokens: promptTokens ?? this.promptTokens,
      completionTokens: completionTokens ?? this.completionTokens,
      totalTokens: totalTokens ?? this.totalTokens,
      estimatedTokens: estimatedTokens ?? this.estimatedTokens,
      audioSeconds: audioSeconds ?? this.audioSeconds,
    );
  }

  int get displayTokens => totalTokens + estimatedTokens;
  bool get hasExactTokens =>
      promptTokens > 0 || completionTokens > 0 || totalTokens > 0;
  bool get hasEstimatedTokens => estimatedTokens > 0;

  Map<String, dynamic> toJson() => {
        'requests': requests,
        'promptTokens': promptTokens,
        'completionTokens': completionTokens,
        'totalTokens': totalTokens,
        'estimatedTokens': estimatedTokens,
        'audioSeconds': audioSeconds,
      };

  factory ApiUsageEntry.fromJson(Map<dynamic, dynamic> json) {
    final hasNewTokenFields = json.containsKey('promptTokens') ||
        json.containsKey('completionTokens') ||
        json.containsKey('totalTokens') ||
        json.containsKey('estimatedTokens');
    final legacyTokens = (json['tokens'] as num?)?.toInt() ?? 0;
    return ApiUsageEntry(
      requests: (json['requests'] as num?)?.toInt() ?? 0,
      promptTokens: (json['promptTokens'] as num?)?.toInt() ?? 0,
      completionTokens: (json['completionTokens'] as num?)?.toInt() ?? 0,
      totalTokens: (json['totalTokens'] as num?)?.toInt() ?? 0,
      estimatedTokens: (json['estimatedTokens'] as num?)?.toInt() ??
          (hasNewTokenFields ? 0 : legacyTokens),
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
    var promptTokens = 0;
    var completionTokens = 0;
    var totalTokens = 0;
    var estimatedTokens = 0;
    var audioSeconds = 0;
    for (final item in entries.entries) {
      if (!item.key.startsWith('$providerId:')) continue;
      requests += item.value.requests;
      promptTokens += item.value.promptTokens;
      completionTokens += item.value.completionTokens;
      totalTokens += item.value.totalTokens;
      estimatedTokens += item.value.estimatedTokens;
      audioSeconds += item.value.audioSeconds;
    }
    return ApiUsageSummary(
      providerId: providerId,
      requests: requests,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      totalTokens: totalTokens,
      estimatedTokens: estimatedTokens,
      audioSeconds: audioSeconds,
    );
  }

  ApiUsageSummary get totalSummary {
    var requests = 0;
    var promptTokens = 0;
    var completionTokens = 0;
    var totalTokens = 0;
    var estimatedTokens = 0;
    var audioSeconds = 0;
    for (final item in entries.values) {
      requests += item.requests;
      promptTokens += item.promptTokens;
      completionTokens += item.completionTokens;
      totalTokens += item.totalTokens;
      estimatedTokens += item.estimatedTokens;
      audioSeconds += item.audioSeconds;
    }
    return ApiUsageSummary(
      providerId: 'auto',
      requests: requests,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      totalTokens: totalTokens,
      estimatedTokens: estimatedTokens,
      audioSeconds: audioSeconds,
    );
  }

  List<String> get activeProviderIds {
    final providers = <String>{};
    for (final item in entries.entries) {
      if (item.value.requests == 0 &&
          item.value.displayTokens == 0 &&
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
    int promptTokens = 0,
    int completionTokens = 0,
    int totalTokens = 0,
    int estimatedTokens = 0,
    int audioSeconds = 0,
  }) {
    final current = entry(key);
    return ApiUsage(
      dateKey: dateKey,
      entries: {
        ...entries,
        key: current.copyWith(
          requests: current.requests + requests,
          promptTokens: current.promptTokens + promptTokens,
          completionTokens: current.completionTokens + completionTokens,
          totalTokens: current.totalTokens + totalTokens,
          estimatedTokens: current.estimatedTokens + estimatedTokens,
          audioSeconds: current.audioSeconds + audioSeconds,
        ),
      },
    );
  }

  int get groqChatRequests =>
      summaryForProvider('groq').requests -
      entry('groq:whisper-large-v3-turbo').requests;
  int get groqChatTokens => summaryForProvider('groq').displayTokens;
  int get groqAudioSeconds => entry('groq:whisper-large-v3-turbo').audioSeconds;
  int get groqWhisperRequests => entry('groq:whisper-large-v3-turbo').requests;

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
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
    required this.estimatedTokens,
    required this.audioSeconds,
  });

  final String providerId;
  final int requests;
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final int estimatedTokens;
  final int audioSeconds;

  int get displayTokens => totalTokens + estimatedTokens;
  bool get hasExactTokens =>
      promptTokens > 0 || completionTokens > 0 || totalTokens > 0;
  bool get hasEstimatedTokens => estimatedTokens > 0;
  bool get isMixedTokenSource => hasExactTokens && hasEstimatedTokens;
  int get audioMinutes => (audioSeconds / 60).floor();
}
