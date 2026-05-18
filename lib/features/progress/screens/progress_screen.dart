import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/conversation_session.dart';
import '../../settings/providers/settings_provider.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  _TimelineRange _range = _TimelineRange.weeks16;

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(progressProvider);
    final sessions = ref.watch(historyProvider);
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
                        progress.level.name,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(value: progress.levelProgress),
                      const SizedBox(height: 8),
                      Text(
                        '${progress.xp} XP toward ${progress.nextLevel.name}',
                        style:
                            TextStyle(color: AppColors.secondaryText(context)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _ConsistencyCard(
                  sessions: sessions,
                  selectedRange: _range,
                  onRangeChanged: (range) => setState(() => _range = range),
                ),
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

enum _TimelineRange {
  weeks16('16 weeks', 16 * 7),
  days365('365 days', 365);

  const _TimelineRange(this.label, this.days);

  final String label;
  final int days;
}

class _ConsistencyCard extends StatelessWidget {
  const _ConsistencyCard({
    required this.sessions,
    required this.selectedRange,
    required this.onRangeChanged,
  });

  final List<ConversationSession> sessions;
  final _TimelineRange selectedRange;
  final ValueChanged<_TimelineRange> onRangeChanged;

  @override
  Widget build(BuildContext context) {
    final timeline = _CalendarTimeline.fromSessions(
      sessions: sessions,
      range: selectedRange,
    );

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
            crossAxisAlignment: CrossAxisAlignment.start,
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
                      'Your real practice activity, colored by how active each day was.',
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
              _RangeToggle(
                selectedRange: selectedRange,
                onChanged: onRangeChanged,
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (timeline.columns.isEmpty)
            const _EmptyCalendar()
          else
            _CalendarHeatmap(timeline: timeline),
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
                '${timeline.activeDays} active days',
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

class _RangeToggle extends StatelessWidget {
  const _RangeToggle({
    required this.selectedRange,
    required this.onChanged,
  });

  final _TimelineRange selectedRange;
  final ValueChanged<_TimelineRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.softSurface(context),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final range in _TimelineRange.values) ...[
            _TogglePill(
              label: range.label,
              selected: selectedRange == range,
              onTap: () => onChanged(range),
            ),
            if (range != _TimelineRange.values.last) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

class _TogglePill extends StatelessWidget {
  const _TogglePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accentPurple : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.secondaryText(context),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarHeatmap extends StatelessWidget {
  const _CalendarHeatmap({required this.timeline});

  final _CalendarTimeline timeline;

  static const double _cell = 14;
  static const double _gap = 5;
  static const double _columnWidth = _cell + _gap;

  @override
  Widget build(BuildContext context) {
    final width = timeline.columns.length * _columnWidth;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (final column in timeline.columns)
                  SizedBox(
                    width: _columnWidth,
                    child: Text(
                      column.monthLabel,
                      style: TextStyle(
                        color: AppColors.secondaryText(context),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final column in timeline.columns)
                  Padding(
                    padding: const EdgeInsets.only(right: _gap),
                    child: Column(
                      children: [
                        for (final day in column.days) ...[
                          _CalendarCell(day: day),
                          if (day != column.days.last)
                            const SizedBox(height: _gap),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarCell extends StatelessWidget {
  const _CalendarCell({required this.day});

  final _PracticeDay day;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message:
          '${DateFormat('MMM d').format(day.date)} • ${day.minutes} min • ${day.sessions} sessions',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(5),
          onTap: () => _showDayDetails(context, day),
          child: Ink(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: _calendarColor(context, day.intensity),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: day.intensity == 0
                    ? AppColors.line(context)
                    : _calendarColor(context, day.intensity).withOpacity(0.9),
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
        1 => const Color(0xFF5E3D94),
        2 => const Color(0xFF7B4AE6),
        3 => const Color(0xFF9768FF),
        _ => const Color(0xFFC4A6FF),
      };
    }
    return switch (level) {
      1 => const Color(0xFFE0D3FF),
      2 => const Color(0xFFC9ABFF),
      3 => const Color(0xFFA571FF),
      _ => const Color(0xFF8A4FE8),
    };
  }

  Future<void> _showDayDetails(BuildContext context, _PracticeDay day) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
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
        1 => const Color(0xFF5E3D94),
        2 => const Color(0xFF7B4AE6),
        3 => const Color(0xFF9768FF),
        _ => const Color(0xFFC4A6FF),
      };
    }
    return switch (level) {
      1 => const Color(0xFFE0D3FF),
      2 => const Color(0xFFC9ABFF),
      3 => const Color(0xFFA571FF),
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

class _EmptyCalendar extends StatelessWidget {
  const _EmptyCalendar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.softSurface(context),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        'Your practice heatmap will appear here after you save a real session.',
        style: TextStyle(
          color: AppColors.secondaryText(context),
          height: 1.35,
        ),
      ),
    );
  }
}

class _CalendarTimeline {
  const _CalendarTimeline({
    required this.columns,
    required this.activeDays,
  });

  final List<_CalendarColumn> columns;
  final int activeDays;

  factory _CalendarTimeline.fromSessions({
    required List<ConversationSession> sessions,
    required _TimelineRange range,
  }) {
    final today = _dateOnly(DateTime.now());
    final firstRequestedDay =
        _dateOnly(today.subtract(Duration(days: range.days - 1)));
    final start = _startOfWeek(firstRequestedDay);
    final activity = <DateTime, _PracticeDay>{};

    for (final session in sessions) {
      if (session.userTurns == 0) continue;
      final day = _dateOnly(session.updatedAt);
      if (day.isBefore(firstRequestedDay) || day.isAfter(today)) continue;
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

    final days = <_PracticeDay>[];
    for (var date = start;
        !date.isAfter(today);
        date = date.add(const Duration(days: 1))) {
      days.add(activity[date] ?? _PracticeDay.empty(date));
    }

    final columns = <_CalendarColumn>[];
    for (var i = 0; i < days.length; i += 7) {
      final chunk = days.skip(i).take(7).toList();
      final firstDay = chunk.first.date;
      final monthLabel =
          firstDay.day <= 7 || i == 0 ? DateFormat('MMM').format(firstDay) : '';
      columns.add(_CalendarColumn(
        monthLabel: monthLabel,
        days: chunk,
      ));
    }

    return _CalendarTimeline(
      columns: columns,
      activeDays: activity.length,
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

class _CalendarColumn {
  const _CalendarColumn({
    required this.monthLabel,
    required this.days,
  });

  final String monthLabel;
  final List<_PracticeDay> days;
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
