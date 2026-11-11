import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'profile_repository.dart';

/// Profil prihlaseneho uzivatele – hlavicka, follows, graf, kalendar.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final socialAsync = ref.watch(followCountsProvider);
    final historyAsync = ref.watch(workoutHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (profile) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(profileProvider);
            ref.invalidate(followCountsProvider);
            ref.invalidate(workoutHistoryProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ProfileHeader(profile: profile),
              const SizedBox(height: 16),
              _SocialCounts(socialAsync: socialAsync),
              const SizedBox(height: 16),
              _WeeklyChart(historyAsync: historyAsync),
              const SizedBox(height: 16),
              const _ActionButtons(),
              const SizedBox(height: 16),
              _TrainingCalendar(historyAsync: historyAsync),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
//  Hlavicka: avatar, jmeno, uprava
// ============================================================

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final ProfileData profile;

  @override
  Widget build(BuildContext context) {
    final photoUrl = profile.profilePhotoUrl;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: _avatarColor(profile.username),
              backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
              child: hasPhoto
                  ? null
                  : Text(
                      _initials(profile.username),
                      style: const TextStyle(
                        fontSize: 24,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.fullName != null && profile.fullName!.isNotEmpty
                        ? profile.fullName!
                        : profile.username,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${profile.username}',
                    style: TextStyle(color: Colors.grey.shade400),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Member since ${profile.memberSince.day}.${profile.memberSince.month}.${profile.memberSince.year}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Edit profile',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/profile/edit'),
            ),
          ],
        ),
      ),
    );
  }

  static Color _avatarColor(String name) {
    const colors = <Color>[
      Colors.teal,
      Colors.indigo,
      Colors.deepOrange,
      Colors.pink,
      Colors.blueGrey,
      Colors.green,
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  static String _initials(String name) {
    final parts = name
        .replaceAll(RegExp(r'[^A-Za-zÀ-ž ]'), '')
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((part) => part.isEmpty ? '' : part[0].toUpperCase())
        .join();
    return parts.isEmpty ? '?' : parts;
  }
}

// ============================================================
//  Pocty followers / following
// ============================================================

class _SocialCounts extends StatelessWidget {
  const _SocialCounts({required this.socialAsync});

  final AsyncValue<FollowCounts> socialAsync;

  @override
  Widget build(BuildContext context) {
    final counts = socialAsync.value;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _CountItem(
              value: counts != null ? '${counts.followers}' : '–',
              label: 'Followers',
            ),
            Container(width: 1, height: 32, color: Colors.grey.shade700),
            _CountItem(
              value: counts != null ? '${counts.following}' : '–',
              label: 'Following',
            ),
          ],
        ),
      ),
    );
  }
}

class _CountItem extends StatelessWidget {
  const _CountItem({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  Graf: hodiny po tydnech
// ============================================================

class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart({required this.historyAsync});

  final AsyncValue<List<WorkoutHistoryEntry>> historyAsync;

  @override
  Widget build(BuildContext context) {
    final entries = historyAsync.value;
    if (entries == null) {
      return const Card(
        child: SizedBox(
          height: 160,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final weekly = computeWeeklyHours(entries, weeks: 8);
    final maxHours =
        weekly.map((w) => w.hours).fold<double>(0, (a, b) => a > b ? a : b);
    final scaleMax = maxHours > 0 ? maxHours : 1.0;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hours per week',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final week in weekly)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (week.hours > 0)
                              Text(
                                _formatHours(week.hours),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade300,
                                ),
                              ),
                            const SizedBox(height: 4),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height:
                                  (week.hours / scaleMax) * 80 + (week.hours > 0 ? 4 : 2),
                              decoration: BoxDecoration(
                                color: week.hours > 0
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey.shade800,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _weekLabel(week.weekStart),
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatHours(double hours) {
    if (hours >= 10) return hours.round().toString();
    return hours.toStringAsFixed(1);
  }

  static String _weekLabel(DateTime weekStart) {
    return '${weekStart.day}.${weekStart.month}';
  }
}

// ============================================================
//  Rychle akce: cviky + pratele
// ============================================================

class _ActionButtons extends StatelessWidget {
  const _ActionButtons();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: () => context.push('/exercises'),
            icon: const Icon(Icons.fitness_center),
            label: const Text('Exercises'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: () => context.push('/profile/friends'),
            icon: const Icon(Icons.people_outline),
            label: const Text('Find friends'),
          ),
        ),
      ],
    );
  }
}

// ============================================================
//  Kalendar: tyden / mesic / rok
// ============================================================

class _TrainingCalendar extends StatefulWidget {
  const _TrainingCalendar({required this.historyAsync});

  final AsyncValue<List<WorkoutHistoryEntry>> historyAsync;

  @override
  State<_TrainingCalendar> createState() => _TrainingCalendarState();
}

class _TrainingCalendarState extends State<_TrainingCalendar> {
  _CalendarMode _mode = _CalendarMode.month;
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _focusedWeekStart = _startOfWeek(DateTime.now());
  int _focusedYear = DateTime.now().year;

  static DateTime _startOfWeek(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.historyAsync.value ?? const <WorkoutHistoryEntry>[];
    final dayCounts = workoutDayCounts(entries);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Training calendar',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                SegmentedButton<_CalendarMode>(
                  segments: const [
                    ButtonSegment(
                      value: _CalendarMode.week,
                      label: Text('Week'),
                    ),
                    ButtonSegment(
                      value: _CalendarMode.month,
                      label: Text('Month'),
                    ),
                    ButtonSegment(
                      value: _CalendarMode.year,
                      label: Text('Year'),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (selection) =>
                      setState(() => _mode = selection.first),
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            switch (_mode) {
              _CalendarMode.week => _buildWeek(dayCounts),
              _CalendarMode.month => _buildMonth(dayCounts),
              _CalendarMode.year => _buildYear(entries),
            },
          ],
        ),
      ),
    );
  }

  // ---------- Tyden ----------

  Widget _buildWeek(Map<DateTime, int> dayCounts) {
    final days = [
      for (var i = 0; i < 7; i++)
        _focusedWeekStart.add(Duration(days: i)),
    ];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 20),
              onPressed: () => setState(() => _focusedWeekStart =
                  _focusedWeekStart.subtract(const Duration(days: 7))),
            ),
            Expanded(
              child: Center(
                child: Text(
                  '${days.first.day}.${days.first.month}. – ${days.last.day}.${days.last.month}.${days.last.year}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 20),
              onPressed: () => setState(() => _focusedWeekStart =
                  _focusedWeekStart.add(const Duration(days: 7))),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final day in days)
              Expanded(
                child: _WeekDayCell(
                  day: day,
                  isToday: day == today,
                  workoutCount: dayCounts[day] ?? 0,
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ---------- Mesic ----------

  Widget _buildMonth(Map<DateTime, int> dayCounts) {
    final year = _focusedMonth.year;
    final month = _focusedMonth.month;
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    // Pondeli jako prvni sloupec.
    final leadingBlanks = firstDay.weekday - 1;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final cells = <Widget>[
      for (var i = 0; i < leadingBlanks; i++) const Expanded(child: SizedBox()),
      for (var day = 1; day <= daysInMonth; day++)
        Expanded(
          child: _MonthDayCell(
            day: day,
            isToday: DateTime(year, month, day) == today,
            workoutCount: dayCounts[DateTime(year, month, day)] ?? 0,
          ),
        ),
    ];
    // Doplnit posledni radek.
    while (cells.length % 7 != 0) {
      cells.add(const Expanded(child: SizedBox()));
    }

    const weekdays = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 20),
              onPressed: () => setState(() => _focusedMonth =
                  DateTime(_focusedMonth.year, _focusedMonth.month - 1)),
            ),
            Expanded(
              child: Center(
                child: Text(
                  '${_monthName(month)} $year',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 20),
              onPressed: () => setState(() => _focusedMonth =
                  DateTime(_focusedMonth.year, _focusedMonth.month + 1)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final w in weekdays)
              Expanded(
                child: Center(
                  child: Text(
                    w,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var row = 0; row < cells.length ~/ 7; row++)
          Row(
            children: [
              for (var col = 0; col < 7; col++) cells[row * 7 + col],
            ],
          ),
      ],
    );
  }

  // ---------- Rok ----------

  Widget _buildYear(List<WorkoutHistoryEntry> entries) {
    final countsByMonth = List<int>.filled(12, 0);
    for (final entry in entries) {
      if (entry.createdAt.year == _focusedYear) {
        countsByMonth[entry.createdAt.month - 1]++;
      }
    }
    final maxCount =
        countsByMonth.fold<int>(0, (a, b) => a > b ? a : b);

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 20),
              onPressed: () => setState(() => _focusedYear--),
            ),
            Expanded(
              child: Center(
                child: Text(
                  '$_focusedYear',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 20),
              onPressed: () => setState(() => _focusedYear++),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (var row = 0; row < 3; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                for (var col = 0; col < 4; col++)
                  Expanded(
                    child: _MonthTile(
                      month: row * 4 + col + 1,
                      count: countsByMonth[row * 4 + col],
                      maxCount: maxCount,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  static String _monthName(int month) {
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return names[month - 1];
  }
}

enum _CalendarMode { week, month, year }

/// Cislo dne v tydennim pohledu.
class _WeekDayCell extends StatelessWidget {
  const _WeekDayCell({
    required this.day,
    required this.isToday,
    required this.workoutCount,
  });

  final DateTime day;
  final bool isToday;
  final int workoutCount;

  static const _weekdayNames = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

  @override
  Widget build(BuildContext context) {
    final active = workoutCount > 0;
    return Column(
      children: [
        Text(
          _weekdayNames[day.weekday - 1],
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 6),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? Theme.of(context).colorScheme.primary
                : isToday
                    ? Colors.grey.shade700
                    : Colors.transparent,
            border: isToday && !active
                ? Border.all(color: Colors.grey.shade500)
                : null,
          ),
          child: Center(
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontWeight: active || isToday ? FontWeight.bold : null,
                color: active ? Colors.white : null,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          active ? '$workoutCount×' : '',
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

/// Cislo dne v mesicnim pohledu.
class _MonthDayCell extends StatelessWidget {
  const _MonthDayCell({
    required this.day,
    required this.isToday,
    required this.workoutCount,
  });

  final int day;
  final bool isToday;
  final int workoutCount;

  @override
  Widget build(BuildContext context) {
    final active = workoutCount > 0;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active
              ? Theme.of(context).colorScheme.primary
              : isToday
                  ? Colors.grey.shade800
                  : null,
          border: isToday && !active
              ? Border.all(color: Colors.grey.shade500)
              : null,
        ),
        child: Center(
          child: Text(
            '$day',
            style: TextStyle(
              fontSize: 13,
              fontWeight: active || isToday ? FontWeight.bold : null,
              color: active ? Colors.white : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// Dlazdice mesice v rocnim pohledu.
class _MonthTile extends StatelessWidget {
  const _MonthTile({
    required this.month,
    required this.count,
    required this.maxCount,
  });

  final int month;
  final int count;
  final int maxCount;

  static const _names = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final intensity = maxCount > 0 ? count / maxCount : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Color.lerp(
            Colors.grey.shade900,
            Theme.of(context).colorScheme.primary,
            intensity * 0.85,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              _names[month - 1],
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: count > 0 ? Colors.white : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
