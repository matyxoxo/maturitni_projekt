import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../home/feed_repository.dart';
import '../home/home_screen.dart';
import 'profile_repository.dart';

/// Profil uzivatele – hlavicka, follows, graf, kalendar, workouty.
///
/// Bez [userId] = vlastni profil (editace, settings, akce).
/// S [userId] = verejny profil cizince (Follow tlacitko, jeho workouty).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, this.userId});

  final String? userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final targetId = userId ?? myId ?? '';
    final isMe = targetId.isNotEmpty && targetId == myId;
    final isOwnTab = userId == null;

    final profileAsync = ref.watch(profileProvider(targetId));
    final socialAsync = ref.watch(followCountsProvider(targetId));
    final historyAsync = ref.watch(workoutHistoryProvider(targetId));

    final title = isMe ? 'My profile' : 'Profile';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (isOwnTab && isMe)
            IconButton(
              tooltip: 'Settings',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.push('/settings'),
            ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Loading profile...',
                style: TextStyle(color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
        error: (err, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      color: AppTheme.textMuted,
                      size: 28,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Could not load this profile.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      '$err',
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        data: (profile) => RefreshIndicator(
          color: AppTheme.accent,
          backgroundColor: AppTheme.surfaceHigh,
          onRefresh: () async {
            ref.invalidate(profileProvider);
            ref.invalidate(followCountsProvider);
            ref.invalidate(workoutHistoryProvider);
            ref.invalidate(userFeedProvider);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              _ProfileHero(
                profile: profile,
                targetId: targetId,
                isMe: isMe,
              ),
              const SizedBox(height: 14),
              _SocialStats(
                profile: profile,
                socialAsync: socialAsync,
                targetId: targetId,
              ),
              if (isMe) ...[
                const SizedBox(height: 14),
                const _QuickActions(),
              ],
              const SizedBox(height: 14),
              _WeeklyChart(historyAsync: historyAsync),
              const SizedBox(height: 14),
              _TrainingCalendar(historyAsync: historyAsync),
              const SizedBox(height: 22),
              _UserWorkoutsSection(userId: targetId),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
//  Hlavicka: avatar, jmeno, follow / edit
// ============================================================

class _ProfileHero extends ConsumerWidget {
  const _ProfileHero({
    required this.profile,
    required this.targetId,
    required this.isMe,
  });

  final ProfileData profile;
  final String targetId;
  final bool isMe;

  Future<void> _toggleFollow(BuildContext context, WidgetRef ref) async {
    final following = ref.read(myFollowingProvider).value ?? <String>{};
    final isFollowing = following.contains(targetId);
    final ok = await setFollow(targetId, follow: !isFollowing);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update follow.')),
      );
      return;
    }
    ref.invalidate(myFollowingProvider);
    ref.invalidate(followCountsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photoUrl = profile.profilePhotoUrl;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
    final isFollowing =
        (ref.watch(myFollowingProvider).value ?? <String>{}).contains(targetId);
    final displayName = profile.fullName != null && profile.fullName!.isNotEmpty
        ? profile.fullName!
        : profile.username;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -90,
            right: -60,
            child: _Glow(
              color: AppTheme.accent.withValues(alpha: 0.35),
              size: 220,
            ),
          ),
          Positioned(
            bottom: -110,
            left: -80,
            child: _Glow(
              color: AppTheme.cyan.withValues(alpha: 0.12),
              size: 200,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _ProfileAvatar(
                      name: profile.username,
                      photoUrl: hasPhoto ? photoUrl : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.7,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '@${profile.username}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.accentBright,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_month_rounded,
                                size: 14,
                                color: AppTheme.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Member since ${profile.memberSince.day}.${profile.memberSince.month}.${profile.memberSince.year}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoPill(
                      icon: Icons.fitness_center_rounded,
                      label: '${profile.workoutCount} workouts',
                    ),
                    if (profile.bodyWeightKg != null)
                      _InfoPill(
                        icon: Icons.monitor_weight_outlined,
                        label: '${_trimWeight(profile.bodyWeightKg!)} kg',
                      ),
                    _InfoPill(
                      icon: Icons.bolt_rounded,
                      label: formatVolume(profile.totalVolumeKg),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (isMe)
                  OutlinedButton.icon(
                    onPressed: () => context.push('/profile/edit'),
                    icon: const Icon(Icons.edit_outlined, size: 19),
                    label: const Text('Edit profile'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.04),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  )
                else
                  FilledButton.icon(
                    onPressed: () => _toggleFollow(context, ref),
                    icon: Icon(
                      isFollowing
                          ? Icons.check_rounded
                          : Icons.person_add_alt_1_rounded,
                      size: 19,
                    ),
                    label: Text(isFollowing ? 'Following' : 'Follow'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: isFollowing
                          ? Colors.white.withValues(alpha: 0.07)
                          : AppTheme.accent,
                      foregroundColor: Colors.white,
                      side: isFollowing
                          ? BorderSide(
                              color: Colors.white.withValues(alpha: 0.14),
                            )
                          : BorderSide.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _trimWeight(double kg) {
    if (kg == kg.roundToDouble()) return kg.round().toString();
    return kg.toStringAsFixed(1);
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.name, required this.photoUrl});

  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppTheme.accentGradient,
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withValues(alpha: 0.4),
            blurRadius: 26,
            spreadRadius: 1,
          ),
        ],
      ),
      child: CircleAvatar(
        radius: 38,
        backgroundColor: AppTheme.surfaceHigh,
        backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
        child: photoUrl == null
            ? Text(
                _initials(name),
                style: const TextStyle(
                  fontSize: 26,
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              )
            : null,
      ),
    );
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

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.accentBright),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFFE8EEFA),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  Statistiky: workouty, objem, followers, following
// ============================================================

class _SocialStats extends StatelessWidget {
  const _SocialStats({
    required this.profile,
    required this.socialAsync,
    required this.targetId,
  });

  final ProfileData profile;
  final AsyncValue<FollowCounts> socialAsync;
  final String targetId;

  void _openList(BuildContext context, String type) {
    context.push('/profile/follow-list?id=$targetId&type=$type');
  }

  @override
  Widget build(BuildContext context) {
    final counts = socialAsync.value;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 6),
        child: Row(
          children: [
            Expanded(
              child: _StatBlock(
                value: '${profile.workoutCount}',
                label: 'Workouts',
              ),
            ),
            const _StatDivider(),
            Expanded(
              child: _StatBlock(
                value: counts != null ? '${counts.followers}' : '–',
                label: 'Followers',
                onTap: () => _openList(context, 'followers'),
              ),
            ),
            const _StatDivider(),
            Expanded(
              child: _StatBlock(
                value: counts != null ? '${counts.following}' : '–',
                label: 'Following',
                onTap: () => _openList(context, 'following'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({required this.value, required this.label, this.onTap});

  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                  color: AppTheme.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      color: Colors.white.withValues(alpha: 0.06),
    );
  }
}

// ============================================================
//  Rychle akce: cviky + pratele
// ============================================================

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionTile(
            icon: Icons.fitness_center_rounded,
            title: 'Exercises',
            subtitle: 'Exercise library',
            onTap: () => context.push('/exercises'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionTile(
            icon: Icons.people_alt_rounded,
            title: 'Find friends',
            subtitle: 'Grow your circle',
            onTap: () => context.push('/find-friends'),
          ),
        ),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.surfaceHigh, AppTheme.surface],
          ),
          borderRadius: radius,
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 19, color: AppTheme.accentBright),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
//  Graf: aktivita (1 tyden / 3 mesice, duration / volume / reps)
// ============================================================

/// Casovy rozsah grafu aktivity.
enum _ActivityRange { week, months }

class _WeeklyChart extends StatefulWidget {
  const _WeeklyChart({required this.historyAsync});

  final AsyncValue<List<WorkoutHistoryEntry>> historyAsync;

  @override
  State<_WeeklyChart> createState() => _WeeklyChartState();
}

class _WeeklyChartState extends State<_WeeklyChart> {
  ActivityMetric _metric = ActivityMetric.duration;
  _ActivityRange _range = _ActivityRange.months;

  static const _weekdayLabels = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  Widget build(BuildContext context) {
    final entries = widget.historyAsync.value;
    if (entries == null) {
      return const Card(
        child: SizedBox(
          height: 220,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final weekly = computeWeeklyActivity(entries, weeks: 12);
    final daily = computeDailyActivity(entries);

    final current = weekly.last.value(_metric);
    final previous =
        weekly.length > 1 ? weekly[weekly.length - 2].value(_metric) : 0.0;
    final delta = previous > 0 ? (current - previous) / previous * 100 : null;
    final summary = _metricSummary(current, _metric);

    // Sloupce a popisky podle zvoleneho rozsahu.
    final values = <double>[];
    final labels = <String>[];
    var highlightIndex = 0;
    if (_range == _ActivityRange.week) {
      values.addAll([for (final day in daily) day.value(_metric)]);
      labels.addAll(_weekdayLabels);
      highlightIndex = DateTime.now().weekday - 1;
    } else {
      values.addAll([for (final week in weekly) week.value(_metric)]);
      for (var i = 0; i < weekly.length; i++) {
        // U 3 mesicu staci datum kazdy druhy tyden (posledni je vzdy videt).
        final showLabel = (weekly.length - 1 - i) % 2 == 0;
        labels.add(
          showLabel
              ? '${weekly[i].weekStart.day}.${weekly[i].weekStart.month}.'
              : '',
        );
      }
      highlightIndex = weekly.length - 1;
    }
    final maxValue = values.fold<double>(0, (a, b) => a > b ? a : b);
    final axisMax = _niceAxisMax(maxValue);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
                      const Text(
                        'Activity',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _range == _ActivityRange.week
                            ? 'This week'
                            : 'Last 3 months',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _RangeSwitch(
                  range: _range,
                  onChanged: (range) => setState(() => _range = range),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            summary.value,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          summary.unit,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.accentBright,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (delta != null) ...[
                  const SizedBox(width: 10),
                  _DeltaPill(delta: delta),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${_metricLabel(_metric)} this week',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 18),
            _ActivityChartBody(
              values: values,
              labels: labels,
              metric: _metric,
              axisMax: axisMax,
              highlightIndex: highlightIndex,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<ActivityMetric>(
                segments: const [
                  ButtonSegment(
                    value: ActivityMetric.duration,
                    label: Text('Duration'),
                  ),
                  ButtonSegment(
                    value: ActivityMetric.volume,
                    label: Text('Volume'),
                  ),
                  ButtonSegment(
                    value: ActivityMetric.reps,
                    label: Text('Reps'),
                  ),
                ],
                selected: {_metric},
                onSelectionChanged: (selection) =>
                    setState(() => _metric = selection.first),
                showSelectedIcon: false,
                expandedInsets: EdgeInsets.zero,
                style: const ButtonStyle(
                  padding: WidgetStatePropertyAll(
                    EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Maly prepinac rozsahu grafu (1W / 3M).
class _RangeSwitch extends StatelessWidget {
  const _RangeSwitch({required this.range, required this.onChanged});

  final _ActivityRange range;
  final ValueChanged<_ActivityRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RangeChip(
            label: '1W',
            selected: range == _ActivityRange.week,
            onTap: () => onChanged(_ActivityRange.week),
          ),
          _RangeChip(
            label: '3M',
            selected: range == _ActivityRange.months,
            onTap: () => onChanged(_ActivityRange.months),
          ),
        ],
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: selected ? AppTheme.accentGradient : null,
          borderRadius: BorderRadius.circular(999),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppTheme.accent.withValues(alpha: 0.3),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}

/// Telicko grafu: y-ova osa podle metriky + sloupce (tydny nebo dny).
class _ActivityChartBody extends StatelessWidget {
  const _ActivityChartBody({
    required this.values,
    required this.labels,
    required this.metric,
    required this.axisMax,
    required this.highlightIndex,
  });

  final List<double> values;
  final List<String> labels;
  final ActivityMetric metric;
  final double axisMax;
  final int highlightIndex;

  static const double _chartHeight = 132;
  static const double _axisWidth = 34;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: _chartHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: _axisWidth,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _AxisLabel(_formatAxis(axisMax, metric)),
                    _AxisLabel(_formatAxis(axisMax / 2, metric)),
                    const _AxisLabel('0'),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Stack(
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        _GridLine(),
                        _GridLine(),
                        _GridLine(),
                      ],
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var i = 0; i < values.length; i++)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 1.5,
                                ),
                                child: FractionallySizedBox(
                                  widthFactor: 0.68,
                                  child: _ActivityBar(
                                    value: values[i],
                                    axisMax: axisMax,
                                    maxHeight: _chartHeight,
                                    isCurrent: i == highlightIndex,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const SizedBox(width: _axisWidth + 6),
            Expanded(
              child: Row(
                children: [
                  for (var i = 0; i < labels.length; i++)
                    Expanded(
                      child: labels[i].isEmpty
                          ? const SizedBox.shrink()
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                labels[i],
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: i == highlightIndex
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: i == highlightIndex
                                      ? Colors.white
                                      : AppTheme.textMuted,
                                ),
                              ),
                            ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Jeden sloupec v grafu (tyden nebo den).
class _ActivityBar extends StatelessWidget {
  const _ActivityBar({
    required this.value,
    required this.axisMax,
    required this.maxHeight,
    required this.isCurrent,
  });

  final double value;
  final double axisMax;
  final double maxHeight;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final ratio = axisMax > 0 ? (value / axisMax).clamp(0.0, 1.0) : 0.0;
    final height = value > 0 ? 6 + ratio * (maxHeight - 12) : 3.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        gradient: value > 0
            ? (isCurrent ? AppTheme.accentGradient : AppTheme.barGradient)
            : null,
        color: value > 0 ? null : Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(6),
        boxShadow: value > 0 && isCurrent
            ? [
                BoxShadow(
                  color: AppTheme.accent.withValues(alpha: 0.45),
                  blurRadius: 14,
                ),
              ]
            : null,
      ),
    );
  }
}

/// Popisek hodnoty na y-ove ose.
class _AxisLabel extends StatelessWidget {
  const _AxisLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: AppTheme.textMuted,
      ),
    );
  }
}

/// Vodorovna mrizka v grafu.
class _GridLine extends StatelessWidget {
  const _GridLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: Colors.white.withValues(alpha: 0.06),
    );
  }
}

/// Zmena oproti minulemu tydnu.
class _DeltaPill extends StatelessWidget {
  const _DeltaPill({required this.delta});

  final double delta;

  @override
  Widget build(BuildContext context) {
    final up = delta >= 0;
    final color = up ? AppTheme.success : AppTheme.danger;
    final text = '${up ? '+' : ''}${delta.round()}%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Formatovani grafu ----------

String _metricLabel(ActivityMetric metric) {
  switch (metric) {
    case ActivityMetric.duration:
      return 'Duration';
    case ActivityMetric.volume:
      return 'Volume';
    case ActivityMetric.reps:
      return 'Reps';
  }
}

/// Hodnota + jednotka pro velky souhrn nad grafem.
({String value, String unit}) _metricSummary(
  double value,
  ActivityMetric metric,
) {
  switch (metric) {
    case ActivityMetric.duration:
      if (value > 0 && value < 1) {
        return (value: '${(value * 60).round()}', unit: 'min');
      }
      final hours =
          value >= 10 ? value.round().toString() : value.toStringAsFixed(1);
      return (value: hours, unit: 'h');
    case ActivityMetric.volume:
      return (value: _thousands(value), unit: 'kg');
    case ActivityMetric.reps:
      return (value: _thousands(value), unit: 'reps');
  }
}

String _formatAxis(double value, ActivityMetric metric) {
  switch (metric) {
    case ActivityMetric.duration:
      if (value >= 10) return value.round().toString();
      return value == value.roundToDouble()
          ? value.round().toString()
          : value.toStringAsFixed(1);
    case ActivityMetric.volume:
      return _compactNumber(value);
    case ActivityMetric.reps:
      return _compactNumber(value);
  }
}

String _compactNumber(double value) {
  if (value >= 1000000) {
    final millions = value / 1000000;
    return '${millions.toStringAsFixed(millions >= 10 ? 0 : 1)}M';
  }
  if (value >= 1000) {
    final thousands = value / 1000;
    return '${thousands.toStringAsFixed(thousands >= 10 ? 0 : 1)}k';
  }
  return value.round().toString();
}

String _thousands(double value) {
  final digits = value.round().abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Zaokrouhli maximum osy na hezke cislo (1, 2, 2.5, 5, 10 x 10^n).
double _niceAxisMax(double value) {
  if (value <= 0) return 1;
  final exponent = (math.log(value) / math.ln10).floor();
  final magnitude = math.pow(10, exponent).toDouble();
  final normalized = value / magnitude;
  final double nice;
  if (normalized <= 1) {
    nice = 1;
  } else if (normalized <= 2) {
    nice = 2;
  } else if (normalized <= 2.5) {
    nice = 2.5;
  } else if (normalized <= 5) {
    nice = 5;
  } else {
    nice = 10;
  }
  return nice * magnitude;
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
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Training calendar',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            const Text(
              'Consistency builds results',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<_CalendarMode>(
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
                expandedInsets: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 16),
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
        _CalendarNav(
          label:
              '${days.first.day}.${days.first.month}. – ${days.last.day}.${days.last.month}.${days.last.year}',
          onPrevious: () => setState(
            () => _focusedWeekStart =
                _focusedWeekStart.subtract(const Duration(days: 7)),
          ),
          onNext: () => setState(
            () => _focusedWeekStart =
                _focusedWeekStart.add(const Duration(days: 7)),
          ),
        ),
        const SizedBox(height: 10),
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
        _CalendarNav(
          label: '${_monthName(month)} $year',
          onPrevious: () => setState(
            () => _focusedMonth =
                DateTime(_focusedMonth.year, _focusedMonth.month - 1),
          ),
          onNext: () => setState(
            () => _focusedMonth =
                DateTime(_focusedMonth.year, _focusedMonth.month + 1),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final w in weekdays)
              Expanded(
                child: Center(
                  child: Text(
                    w,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
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
    final maxCount = countsByMonth.fold<int>(0, (a, b) => a > b ? a : b);

    return Column(
      children: [
        _CalendarNav(
          label: '$_focusedYear',
          onPrevious: () => setState(() => _focusedYear--),
          onNext: () => setState(() => _focusedYear++),
        ),
        const SizedBox(height: 12),
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

class _CalendarNav extends StatelessWidget {
  const _CalendarNav({
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _NavButton(icon: Icons.chevron_left_rounded, onPressed: onPrevious),
        Expanded(
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        _NavButton(icon: Icons.chevron_right_rounded, onPressed: onNext),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 19),
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.05),
        foregroundColor: AppTheme.textMuted,
        minimumSize: const Size(34, 34),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(11),
        ),
      ),
    );
  }
}

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
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: active ? AppTheme.barGradient : null,
            color: active
                ? null
                : isToday
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isToday && !active
                ? Border.all(color: AppTheme.accent.withValues(alpha: 0.7))
                : null,
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppTheme.accent.withValues(alpha: 0.35),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontWeight: active || isToday ? FontWeight.w700 : null,
                color: active
                    ? Colors.white
                    : isToday
                        ? AppTheme.accentBright
                        : null,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          active ? '$workoutCount×' : '',
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: AppTheme.accentBright,
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
      padding: const EdgeInsets.all(2.5),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          gradient: active ? AppTheme.barGradient : null,
          color: active
              ? null
              : isToday
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          border: isToday && !active
              ? Border.all(color: AppTheme.accent.withValues(alpha: 0.7))
              : null,
          boxShadow: active
              ? [
                  BoxShadow(
                    color: AppTheme.accent.withValues(alpha: 0.32),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            '$day',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: active || isToday ? FontWeight.w700 : null,
              color: active
                  ? Colors.white
                  : isToday
                      ? AppTheme.accentBright
                      : null,
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
    final active = count > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          gradient: active
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.accent.withValues(alpha: 0.25 + 0.55 * intensity),
                    AppTheme.accent.withValues(alpha: 0.10 + 0.30 * intensity),
                  ],
                )
              : null,
          color: active ? null : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? AppTheme.accent.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Column(
          children: [
            Text(
              _names[month - 1],
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: active ? Colors.white : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  Workouty uzivatele (karty na profilu)
// ============================================================

/// Seznam workoutu udaneho uzivatele (stejne karty jako feed).
class _UserWorkoutsSection extends ConsumerWidget {
  const _UserWorkoutsSection({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(userFeedProvider(userId));
    final workouts = feedAsync.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Recent workouts',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            if (workouts != null && workouts.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${workouts.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accentBright,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        feedAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => Text(
            'Error: $err',
            style: const TextStyle(color: AppTheme.textMuted),
          ),
          data: (workouts) {
            if (workouts.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 26,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.fitness_center_rounded,
                      color: AppTheme.textMuted,
                      size: 28,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'No workouts yet.',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            }
            return Column(
              children: [
                for (final workout in workouts)
                  FeedWorkoutCard(
                    key: ValueKey(workout.workoutId),
                    workout: workout,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
