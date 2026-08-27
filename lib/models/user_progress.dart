import '../core/constants/app_constants.dart';

class UserProgress {
  const UserProgress({
    this.xp = 0,
    this.streak = 0,
    this.totalConversations = 0,
    this.minutesPracticed = 0,
    this.wordsLearned = 0,
    this.errorsCorrected = 0,
    this.todayMinutesPracticed = 0,
    this.todayDateKey = '',
    this.activityByDate = const {},
  });

  final int xp;
  final int streak;
  final int totalConversations;
  final int minutesPracticed;
  final int wordsLearned;
  final int errorsCorrected;
  final int todayMinutesPracticed;
  final String todayDateKey;
  final Map<String, DailyPracticeActivity> activityByDate;

  static String dateKey(DateTime date) {
    final now = date.toLocal();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  static String todayKey() => dateKey(DateTime.now());

  UserProgress normalizedForToday() {
    final today = todayKey();
    final normalized = todayDateKey == today
        ? this
        : copyWith(todayDateKey: today, todayMinutesPracticed: 0);
    if (normalized.activityByDate.isEmpty) return normalized;
    return normalized.copyWith(
      streak: _calculateStreak(normalized.activityByDate, DateTime.now()),
    );
  }

  LevelDefinition get level {
    var current = AppConstants.levels.first;
    for (final item in AppConstants.levels) {
      if (xp >= item.xpRequired) current = item;
    }
    return current;
  }

  LevelDefinition get nextLevel {
    return AppConstants.levels.firstWhere(
      (item) => item.xpRequired > xp,
      orElse: () => AppConstants.levels.last,
    );
  }

  double get levelProgress {
    final current = level.xpRequired;
    final next = nextLevel.xpRequired;
    if (next == current) return 1;
    return ((xp - current) / (next - current)).clamp(0, 1).toDouble();
  }

  UserProgress copyWith({
    int? xp,
    int? streak,
    int? totalConversations,
    int? minutesPracticed,
    int? wordsLearned,
    int? errorsCorrected,
    int? todayMinutesPracticed,
    String? todayDateKey,
    Map<String, DailyPracticeActivity>? activityByDate,
  }) {
    return UserProgress(
      xp: xp ?? this.xp,
      streak: streak ?? this.streak,
      totalConversations: totalConversations ?? this.totalConversations,
      minutesPracticed: minutesPracticed ?? this.minutesPracticed,
      wordsLearned: wordsLearned ?? this.wordsLearned,
      errorsCorrected: errorsCorrected ?? this.errorsCorrected,
      todayMinutesPracticed:
          todayMinutesPracticed ?? this.todayMinutesPracticed,
      todayDateKey: todayDateKey ?? this.todayDateKey,
      activityByDate: activityByDate ?? this.activityByDate,
    );
  }

  Map<String, dynamic> toJson() => {
        'xp': xp,
        'streak': streak,
        'totalConversations': totalConversations,
        'minutesPracticed': minutesPracticed,
        'wordsLearned': wordsLearned,
        'errorsCorrected': errorsCorrected,
        'todayMinutesPracticed': todayMinutesPracticed,
        'todayDateKey': todayDateKey,
        'activityByDate': activityByDate.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
      };

  factory UserProgress.fromJson(Map<dynamic, dynamic> json) {
    return UserProgress(
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      streak: (json['streak'] as num?)?.toInt() ?? 0,
      totalConversations: (json['totalConversations'] as num?)?.toInt() ?? 0,
      minutesPracticed: (json['minutesPracticed'] as num?)?.toInt() ?? 0,
      wordsLearned: (json['wordsLearned'] as num?)?.toInt() ?? 0,
      errorsCorrected: (json['errorsCorrected'] as num?)?.toInt() ?? 0,
      todayMinutesPracticed:
          (json['todayMinutesPracticed'] as num?)?.toInt() ?? 0,
      todayDateKey: json['todayDateKey']?.toString() ?? '',
      activityByDate: (json['activityByDate'] as Map?)?.map(
            (key, value) => MapEntry(
              key.toString(),
              value is Map
                  ? DailyPracticeActivity.fromJson(value)
                  : const DailyPracticeActivity(),
            ),
          ) ??
          const {},
    ).normalizedForToday();
  }

  static int _calculateStreak(
    Map<String, DailyPracticeActivity> activity,
    DateTime now,
  ) {
    var day = DateTime(now.year, now.month, now.day);
    if (!(activity[dateKey(day)]?.isActive ?? false)) {
      day = day.subtract(const Duration(days: 1));
      if (!(activity[dateKey(day)]?.isActive ?? false)) return 0;
    }

    var count = 0;
    while (activity[dateKey(day)]?.isActive ?? false) {
      count++;
      day = day.subtract(const Duration(days: 1));
    }
    return count;
  }
}

class DailyPracticeActivity {
  const DailyPracticeActivity({
    this.minutes = 0,
    this.sessions = 0,
    this.corrections = 0,
  });

  final int minutes;
  final int sessions;
  final int corrections;

  bool get isActive => minutes > 0 || sessions > 0;

  DailyPracticeActivity copyWith({
    int? minutes,
    int? sessions,
    int? corrections,
  }) {
    return DailyPracticeActivity(
      minutes: minutes ?? this.minutes,
      sessions: sessions ?? this.sessions,
      corrections: corrections ?? this.corrections,
    );
  }

  Map<String, dynamic> toJson() => {
        'minutes': minutes,
        'sessions': sessions,
        'corrections': corrections,
      };

  factory DailyPracticeActivity.fromJson(Map<dynamic, dynamic> json) {
    return DailyPracticeActivity(
      minutes: (json['minutes'] as num?)?.toInt() ?? 0,
      sessions: (json['sessions'] as num?)?.toInt() ?? 0,
      corrections: (json['corrections'] as num?)?.toInt() ?? 0,
    );
  }
}
