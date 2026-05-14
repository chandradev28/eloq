import '../core/constants/app_constants.dart';

class UserProgress {
  const UserProgress({
    this.xp = 0,
    this.streak = 0,
    this.totalConversations = 0,
    this.minutesPracticed = 0,
    this.wordsLearned = 0,
    this.errorsCorrected = 0,
  });

  final int xp;
  final int streak;
  final int totalConversations;
  final int minutesPracticed;
  final int wordsLearned;
  final int errorsCorrected;

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
  }) {
    return UserProgress(
      xp: xp ?? this.xp,
      streak: streak ?? this.streak,
      totalConversations: totalConversations ?? this.totalConversations,
      minutesPracticed: minutesPracticed ?? this.minutesPracticed,
      wordsLearned: wordsLearned ?? this.wordsLearned,
      errorsCorrected: errorsCorrected ?? this.errorsCorrected,
    );
  }

  Map<String, dynamic> toJson() => {
        'xp': xp,
        'streak': streak,
        'totalConversations': totalConversations,
        'minutesPracticed': minutesPracticed,
        'wordsLearned': wordsLearned,
        'errorsCorrected': errorsCorrected,
      };

  factory UserProgress.fromJson(Map<dynamic, dynamic> json) {
    return UserProgress(
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      streak: (json['streak'] as num?)?.toInt() ?? 0,
      totalConversations: (json['totalConversations'] as num?)?.toInt() ?? 0,
      minutesPracticed: (json['minutesPracticed'] as num?)?.toInt() ?? 0,
      wordsLearned: (json['wordsLearned'] as num?)?.toInt() ?? 0,
      errorsCorrected: (json['errorsCorrected'] as num?)?.toInt() ?? 0,
    );
  }
}
