import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/conversation_session.dart';
import '../../../models/user_progress.dart';
import '../../settings/providers/settings_provider.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    final sessions = ref.watch(historyProvider);
    final rank = _ProgressRankSnapshot.from(
      progress: progress,
      sessions: sessions,
    );
    final stats = [
      ('XP', progress.xp.toString(), Icons.star_rounded),
      (
        'Streak',
        '${progress.streak} days',
        Icons.local_fire_department_rounded,
      ),
      (
        'Sessions',
        progress.totalConversations.toString(),
        Icons.forum_rounded,
      ),
      (
        'Corrections',
        progress.errorsCorrected.toString(),
        Icons.lightbulb_rounded,
      ),
    ];

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 118),
              children: [
                Text(
                  'Progress',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface(context),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.purpleDeep.withOpacity(0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Eloq rank',
                        style: TextStyle(
                          color: AppColors.secondaryText(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        rank.current.name,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Built from your real practice time, sessions, active days, streak, and corrections.',
                        style: TextStyle(
                          color: AppColors.secondaryText(context),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _DayMetricChip(
                            icon: Icons.schedule_rounded,
                            text: '${progress.minutesPracticed} min',
                          ),
                          _DayMetricChip(
                            icon: Icons.calendar_month_rounded,
                            text: '${rank.activeDays} active days',
                          ),
                          _DayMetricChip(
                            icon: Icons.forum_rounded,
                            text: '${progress.totalConversations} sessions',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(value: rank.progress),
                      const SizedBox(height: 8),
                      Text(
                        '${rank.score} training score toward ${rank.next.name}',
                        style:
                            TextStyle(color: AppColors.secondaryText(context)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _ConsistencyCard(sessions: sessions),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: stats.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.25,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) {
                    final stat = stats[index];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface(context),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.softSurface(context),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(stat.$3, color: AppColors.accentPurple),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                stat.$2,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                              Text(
                                stat.$1,
                                style: TextStyle(
                                  color: AppColors.secondaryText(context),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConsistencyCard extends StatelessWidget {
  const _ConsistencyCard({required this.sessions});

  final List<ConversationSession> sessions;

  @override
  Widget build(BuildContext context) {
    final calendar = _MonthCalendar.fromSessions(sessions: sessions);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.purpleDeep.withOpacity(0.06),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Consistency',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Track your real practice days in a simple monthly view.',
                      style: TextStyle(
                        color: AppColors.secondaryText(context),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.softSurface(context),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  calendar.monthLabel,
                  style: const TextStyle(
                    color: AppColors.accentPurple,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryTile(
                  label: 'This week',
                  value: '${calendar.weekActiveDays}',
                  helper: 'active days',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryTile(
                  label: 'This month',
                  value: '${calendar.monthActiveDays}',
                  helper: 'active days',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryTile(
                  label: 'This year',
                  value: '${calendar.yearActiveDays}',
                  helper: 'active days',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _MonthCalendarGrid(calendar: calendar),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                'Less',
                style: TextStyle(
                  color: AppColors.secondaryText(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              for (var i = 0; i < 5; i++) ...[
                _LegendSwatch(level: i),
                if (i != 4) const SizedBox(width: 6),
              ],
              const SizedBox(width: 8),
              Text(
                'More',
                style: TextStyle(
                  color: AppColors.secondaryText(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${calendar.monthMinutes} min this month',
                style: const TextStyle(
                  color: AppColors.accentPurple,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.helper,
  });

  final String label;
  final String value;
  final String helper;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.softSurface(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.secondaryText(context),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: AppColors.primaryText(context),
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            helper,
            style: TextStyle(
              color: AppColors.secondaryText(context),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthCalendarGrid extends StatelessWidget {
  const _MonthCalendarGrid({required this.calendar});

  final _MonthCalendar calendar;

  @override
  Widget build(BuildContext context) {
    const weekDays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return Column(
      children: [
        Row(
          children: [
            for (final day in weekDays)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      day,
                      style: TextStyle(
                        color: AppColors.secondaryText(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: calendar.slots.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.94,
          ),
          itemBuilder: (context, index) {
            final slot = calendar.slots[index];
            if (!slot.hasDate) {
              return const SizedBox.shrink();
            }
            return _CalendarCell(day: slot.day!);
          },
        ),
      ],
    );
  }
}

class _CalendarCell extends StatelessWidget {
  const _CalendarCell({required this.day});

  final _PracticeDay day;

  @override
  Widget build(BuildContext context) {
    final surface = _calendarColor(context, day.intensity);
    final textColor = day.intensity >= 3
        ? Colors.white
        : AppColors.primaryText(context);

    return Tooltip(
      message:
          '${DateFormat('MMM d').format(day.date)} - ${day.minutes} min - ${day.sessions} sessions',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showDayDetails(context, day),
          child: Ink(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: day.intensity == 0
                    ? AppColors.line(context)
                    : surface.withOpacity(0.96),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${day.date.day}',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  if (day.hasPractice)
                    Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: textColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            '${day.minutes}m',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: textColor.withOpacity(0.9),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _calendarColor(BuildContext context, int level) {
    if (level == 0) {
      return AppColors.softSurface(context);
    }
    if (AppColors.isDark(context)) {
      return switch (level) {
        1 => const Color(0xFF4D356F),
        2 => const Color(0xFF6A43AB),
        3 => const Color(0xFF8956E8),
        _ => const Color(0xFFA871FF),
      };
    }
    return switch (level) {
      1 => const Color(0xFFEEE5FF),
      2 => const Color(0xFFD8C1FF),
      3 => const Color(0xFFB287FF),
      _ => const Color(0xFF8A4FE8),
    };
  }

  Future<void> _showDayDetails(BuildContext context, _PracticeDay day) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final bottomInset = MediaQuery.of(context).padding.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset + 96),
          child: SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.line(context)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEEE, MMM d').format(day.date),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    day.hasPractice
                        ? 'Saved from your real practice sessions.'
                        : 'No practice was saved on this day.',
                    style: TextStyle(
                      color: AppColors.secondaryText(context),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _DayMetricChip(
                        icon: Icons.schedule_rounded,
                        text: '${day.minutes} min',
                      ),
                      _DayMetricChip(
                        icon: Icons.forum_rounded,
                        text: '${day.sessions} sessions',
                      ),
                      _DayMetricChip(
                        icon: Icons.lightbulb_rounded,
                        text: '${day.corrections} corrections',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LegendSwatch extends StatelessWidget {
  const _LegendSwatch({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: _calendarLegendColor(context, level),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.line(context)),
      ),
    );
  }

  Color _calendarLegendColor(BuildContext context, int level) {
    if (level == 0) return AppColors.softSurface(context);
    if (AppColors.isDark(context)) {
      return switch (level) {
        1 => const Color(0xFF4D356F),
        2 => const Color(0xFF6A43AB),
        3 => const Color(0xFF8956E8),
        _ => const Color(0xFFA871FF),
      };
    }
    return switch (level) {
      1 => const Color(0xFFEEE5FF),
      2 => const Color(0xFFD8C1FF),
      3 => const Color(0xFFB287FF),
      _ => const Color(0xFF8A4FE8),
    };
  }
}

class _DayMetricChip extends StatelessWidget {
  const _DayMetricChip({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.softSurface(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.accentPurple),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: AppColors.primaryText(context),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthCalendar {
  const _MonthCalendar({
    required this.monthLabel,
    required this.slots,
    required this.visibleDays,
    required this.weekActiveDays,
    required this.monthActiveDays,
    required this.yearActiveDays,
    required this.monthMinutes,
  });

  final String monthLabel;
  final List<_CalendarSlot> slots;
  final List<_PracticeDay> visibleDays;
  final int weekActiveDays;
  final int monthActiveDays;
  final int yearActiveDays;
  final int monthMinutes;

  factory _MonthCalendar.fromSessions({
    required List<ConversationSession> sessions,
  }) {
    final today = _dateOnly(DateTime.now());
    final monthStart = DateTime(today.year, today.month, 1);
    final nextMonthStart = today.month == 12
        ? DateTime(today.year + 1, 1, 1)
        : DateTime(today.year, today.month + 1, 1);
    final monthEnd = nextMonthStart.subtract(const Duration(days: 1));
    final yearStart = DateTime(today.year, 1, 1);
    final weekStart = _startOfWeek(today);
    final activity = <DateTime, _PracticeDay>{};

    for (final session in sessions) {
      if (session.userTurns == 0) continue;
      final day = _dateOnly(session.updatedAt);
      final duration = session.updatedAt.difference(session.startedAt);
      final estimatedMinutes = math.max(
        1,
        duration.inMinutes.clamp(1, 45),
      );
      final existing = activity[day];
      if (existing == null) {
        activity[day] = _PracticeDay(
          date: day,
          sessions: 1,
          minutes: estimatedMinutes,
          corrections: session.correctionCount,
        );
      } else {
        activity[day] = existing.copyWith(
          sessions: existing.sessions + 1,
          minutes: existing.minutes + estimatedMinutes,
          corrections: existing.corrections + session.correctionCount,
        );
      }
    }

    final monthDays = <_PracticeDay>[];
    for (var date = monthStart;
        !date.isAfter(monthEnd);
        date = date.add(const Duration(days: 1))) {
      monthDays.add(activity[date] ?? _PracticeDay.empty(date));
    }

    final slots = <_CalendarSlot>[];
    final leading = monthStart.weekday % 7;
    for (var i = 0; i < leading; i++) {
      slots.add(const _CalendarSlot.empty());
    }
    for (final day in monthDays) {
      slots.add(_CalendarSlot(day: day));
    }
    while (slots.length % 7 != 0) {
      slots.add(const _CalendarSlot.empty());
    }

    final weekActiveDays = activity.keys
        .where((day) => !day.isBefore(weekStart) && !day.isAfter(today))
        .length;
    final monthActiveDays = monthDays.where((day) => day.hasPractice).length;
    final yearActiveDays = activity.keys
        .where((day) => !day.isBefore(yearStart) && !day.isAfter(today))
        .length;
    final monthMinutes =
        monthDays.fold<int>(0, (total, day) => total + day.minutes);

    return _MonthCalendar(
      monthLabel: DateFormat('MMMM yyyy').format(monthStart),
      slots: slots,
      visibleDays: monthDays,
      weekActiveDays: weekActiveDays,
      monthActiveDays: monthActiveDays,
      yearActiveDays: yearActiveDays,
      monthMinutes: monthMinutes,
    );
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static DateTime _startOfWeek(DateTime date) {
    final daysFromSunday = date.weekday % 7;
    return _dateOnly(date.subtract(Duration(days: daysFromSunday)));
  }
}

class _CalendarSlot {
  const _CalendarSlot({this.day});
  const _CalendarSlot.empty() : day = null;

  final _PracticeDay? day;

  bool get hasDate => day != null;
}

class _PracticeDay {
  const _PracticeDay({
    required this.date,
    required this.sessions,
    required this.minutes,
    required this.corrections,
  });

  final DateTime date;
  final int sessions;
  final int minutes;
  final int corrections;

  factory _PracticeDay.empty(DateTime date) {
    return _PracticeDay(
      date: date,
      sessions: 0,
      minutes: 0,
      corrections: 0,
    );
  }

  bool get hasPractice => sessions > 0;

  int get intensity {
    if (!hasPractice) return 0;
    if (minutes >= 30 || sessions >= 4) return 4;
    if (minutes >= 18 || sessions >= 3) return 3;
    if (minutes >= 8 || sessions >= 2) return 2;
    return 1;
  }

  _PracticeDay copyWith({
    int? sessions,
    int? minutes,
    int? corrections,
  }) {
    return _PracticeDay(
      date: date,
      sessions: sessions ?? this.sessions,
      minutes: minutes ?? this.minutes,
      corrections: corrections ?? this.corrections,
    );
  }
}

class _ProgressRankDefinition {
  const _ProgressRankDefinition(this.name, this.requiredScore);

  final String name;
  final int requiredScore;
}

class _ProgressRankSnapshot {
  const _ProgressRankSnapshot({
    required this.current,
    required this.next,
    required this.score,
    required this.progress,
    required this.activeDays,
  });

  final _ProgressRankDefinition current;
  final _ProgressRankDefinition next;
  final int score;
  final double progress;
  final int activeDays;

  static const _ranks = [
    _ProgressRankDefinition('Beginner', 0),
    _ProgressRankDefinition('Building', 180),
    _ProgressRankDefinition('Active', 420),
    _ProgressRankDefinition('Consistent', 780),
    _ProgressRankDefinition('Committed', 1220),
    _ProgressRankDefinition('Focused', 1780),
    _ProgressRankDefinition('Fluent', 2520),
    _ProgressRankDefinition('Advanced', 3400),
    _ProgressRankDefinition('Eloquent', 4600),
  ];

  factory _ProgressRankSnapshot.from({
    required UserProgress progress,
    required List<ConversationSession> sessions,
  }) {
    final uniqueDays = <String>{};
    for (final session in sessions) {
      if (session.userTurns == 0) continue;
      final date = session.updatedAt;
      uniqueDays.add(
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}',
      );
    }

    final activeDays = uniqueDays.length;
    final score = (progress.minutesPracticed * 4) +
        (progress.totalConversations * 28) +
        (progress.errorsCorrected * 6) +
        (progress.streak * 40) +
        (activeDays * 52);

    var current = _ranks.first;
    for (final rank in _ranks) {
      if (score >= rank.requiredScore) {
        current = rank;
      }
    }

    final next = _ranks.firstWhere(
      (rank) => rank.requiredScore > score,
      orElse: () => _ranks.last,
    );

    final progressValue = current == next
        ? 1.0
        : ((score - current.requiredScore) /
                (next.requiredScore - current.requiredScore))
            .clamp(0, 1)
            .toDouble();

    return _ProgressRankSnapshot(
      current: current,
      next: next,
      score: score,
      progress: progressValue,
      activeDays: activeDays,
    );
  }
}
