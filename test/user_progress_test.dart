import 'package:eloq/models/user_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('daily activity survives persistence and calculates the streak', () {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final progress = UserProgress(
      minutesPracticed: 18,
      totalConversations: 3,
      todayDateKey: UserProgress.dateKey(now),
      activityByDate: {
        UserProgress.dateKey(now): const DailyPracticeActivity(
          minutes: 8,
          sessions: 1,
          corrections: 2,
        ),
        UserProgress.dateKey(yesterday): const DailyPracticeActivity(
          minutes: 10,
          sessions: 2,
        ),
      },
    );

    final restored = UserProgress.fromJson(progress.toJson());

    expect(restored.streak, 2);
    expect(restored.activityByDate[UserProgress.dateKey(now)]?.minutes, 8);
    expect(restored.activityByDate[UserProgress.dateKey(now)]?.sessions, 1);
  });

  test('legacy progress without activity keeps its stored streak', () {
    final restored = UserProgress.fromJson({
      'streak': 4,
      'minutesPracticed': 20,
      'todayDateKey': UserProgress.todayKey(),
    });

    expect(restored.streak, 4);
    expect(restored.activityByDate, isEmpty);
  });
}
