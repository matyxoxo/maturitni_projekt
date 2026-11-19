import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import 'rank_engine.dart';
import 'rank_model.dart';
import 'rank_repository.dart';
import 'rank_widgets.dart';

/// Zalozka Rank – osobni rank strom z historie treninku.
class RankScreen extends ConsumerWidget {
  const RankScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(rankReportProvider);
    try {
      await ref.read(rankReportProvider.future);
    } catch (_) {
      // Chybu zobrazi sama obrazovka pres error stav.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(rankReportProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rank'),
        actions: [
          IconButton(
            tooltip: 'How ranks work',
            onPressed: () => showRankInfoSheet(context),
            icon: const Icon(Icons.info_outline_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        edgeOffset: 8,
        child: report.when(
          loading: () => const _CenteredScroll(
            child: CircularProgressIndicator(),
          ),
          error: (error, _) => _CenteredScroll(
            child: _ErrorState(
              message: '$error',
              onRetry: () => _refresh(ref),
            ),
          ),
          data: (data) => _RankBody(report: data),
        ),
      ),
    );
  }
}

class _RankBody extends StatelessWidget {
  const _RankBody({required this.report});

  final RankReport report;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
      children: [
        _OverallCard(report: report),
        if (!report.hasBodyWeight) ...[
          const SizedBox(height: 14),
          const _MissingWeightCard(),
        ],
        const SizedBox(height: 26),
        _SectionHeader(
          title: 'Muscle groups',
          trailing: report.rankedExerciseCount == 0
              ? null
              : '${report.rankedExerciseCount} ranked',
        ),
        const SizedBox(height: 12),
        if (report.groups.isEmpty)
          const _EmptyGroupsCard()
        else
          for (final group in report.groups) ...[
            _GroupCard(group: group),
            const SizedBox(height: 12),
          ],
        if (report.notRankedExerciseNames.isNotEmpty) ...[
          const SizedBox(height: 4),
          _NotRankedCard(names: report.notRankedExerciseNames),
        ],
        const SizedBox(height: 20),
        const _FooterNote(),
      ],
    );
  }
}

// ============================================================
//  Celkovy rank
// ============================================================

class _OverallCard extends StatelessWidget {
  const _OverallCard({required this.report});

  final RankReport report;

  @override
  Widget build(BuildContext context) {
    final rank = report.global;
    final groupsWithRank = report.groups.where((g) => g.rank != null).length;

    final String subtitle;
    if (rank == null) {
      subtitle = report.globalUnlockRemaining == 1
          ? 'Rank 1 more exercise to unlock'
          : 'Rank ${report.globalUnlockRemaining} more exercises to unlock';
    } else if (rank.tier == RankTier.alpha) {
      subtitle = 'Top 1 % — the highest rank';
    } else {
      subtitle =
          'Average of $groupsWithRank muscle groups · ${report.rankedExerciseCount} exercises';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: AppTheme.heroGradient,
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        boxShadow: rank == null
            ? null
            : [
                BoxShadow(
                  color: rank.tier.color.withValues(alpha: 0.12),
                  blurRadius: 44,
                  offset: const Offset(0, 14),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RankBadge(rank: rank, size: 84),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'OVERALL RANK',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.3,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Text(
                            report.sex.label.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      rank?.label ?? 'Locked',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        color: rank?.tier.color,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (rank != null)
            RankProgressBar(rank: rank)
          else
            _UnlockBar(
              current: report.rankedExerciseCount,
              target: kRankGlobalUnlockCount,
            ),
        ],
      ),
    );
  }
}

class _UnlockBar extends StatelessWidget {
  const _UnlockBar({required this.current, required this.target});

  final int current;
  final int target;

  @override
  Widget build(BuildContext context) {
    final value = (current / target).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              size: 14,
              color: AppTheme.textMuted,
            ),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Overall rank',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted,
                ),
              ),
            ),
            Text(
              '$current / $target',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.accentBright,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 6,
            backgroundColor: Colors.white.withValues(alpha: 0.06),
            color: AppTheme.accent,
          ),
        ),
      ],
    );
  }
}

class _MissingWeightCard extends StatelessWidget {
  const _MissingWeightCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.accent.withValues(alpha: 0.14),
            ),
            child: const Icon(
              Icons.monitor_weight_outlined,
              size: 20,
              color: AppTheme.accentBright,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add your bodyweight',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 3),
                Text(
                  'Ranks compare your lifts with lifters of the same weight.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => context.push('/profile/edit'),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  Skupiny a podsvaly
// ============================================================

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group});

  final RankGroup group;

  @override
  Widget build(BuildContext context) {
    final color = group.rank?.tier.color ?? AppTheme.outline;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.12),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Icon(
                    rankGroupIcon(group.name),
                    size: 21,
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        group.isEmpty
                            ? 'No ranked sets yet'
                            : '${group.rankedExercises} ranked ${group.rankedExercises == 1 ? 'exercise' : 'exercises'}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                RankPill(rank: group.rank),
              ],
            ),
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < group.muscles.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                color: Colors.white.withValues(alpha: 0.05),
                indent: 4,
                endIndent: 4,
              ),
            _MuscleRow(group: group, muscle: group.muscles[i]),
          ],
        ],
      ),
    );
  }
}

class _MuscleRow extends StatelessWidget {
  const _MuscleRow({required this.group, required this.muscle});

  final RankGroup group;
  final RankMuscle muscle;

  @override
  Widget build(BuildContext context) {
    final hasData = muscle.exercises.isNotEmpty;
    final color = muscle.rank?.tier.color ?? AppTheme.outline;

    void open() {
      final location = Uri(
        path: '/rank/muscle',
        queryParameters: {'group': group.name, 'muscle': muscle.name},
      ).toString();
      context.push(location);
    }

    return InkWell(
      onTap: hasData ? open : null,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 26,
              decoration: BoxDecoration(
                color: hasData
                    ? color.withValues(alpha: 0.85)
                    : AppTheme.outline.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    muscle.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: hasData ? null : AppTheme.textMuted,
                    ),
                  ),
                  if (hasData) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${muscle.exercises.length} ${muscle.exercises.length == 1 ? 'exercise' : 'exercises'}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            RankPill(rank: muscle.rank, dense: true),
            SizedBox(
              width: 18,
              child: hasData
                  ? const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppTheme.textMuted,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  Vedlejsi stavy
// ============================================================

class _NotRankedCard extends StatelessWidget {
  const _NotRankedCard({required this.names});

  final List<String> names;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: AppTheme.textMuted,
          collapsedIconColor: AppTheme.textMuted,
          title: Text(
            'Not ranked yet (${names.length})',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          subtitle: const Text(
            'These exercises have no strength standard yet',
            style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final name in names.take(40))
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.07),
                        ),
                      ),
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
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
}

class _EmptyGroupsCard extends StatelessWidget {
  const _EmptyGroupsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: const Text(
        'Log a ranked exercise and your muscle groups will fill in here.',
        style: TextStyle(fontSize: 13, height: 1.45, color: AppTheme.textMuted),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: AppTheme.textMuted,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
      ],
    );
  }
}

class _FooterNote extends StatelessWidget {
  const _FooterNote();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Ranks come from your own workout history and bodyweight — there is no '
      'leaderboard. Only completed working sets count; warm-ups are ignored.',
      style: TextStyle(fontSize: 11, height: 1.5, color: AppTheme.textMuted),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 36,
            color: AppTheme.textMuted,
          ),
          const SizedBox(height: 14),
          const Text(
            'Could not load your ranks',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

class _CenteredScroll extends StatelessWidget {
  const _CenteredScroll({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: child),
        ),
      ),
    );
  }
}

// ============================================================
//  Vysvetlivky
// ============================================================

Future<void> showRankInfoSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.bg,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          const Text(
            'How ranks work',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Every lift is compared with lifters of the same bodyweight. '
            'Your rank is built from the bottom up: exercise → sub-muscle → '
            'muscle group → overall rank.',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 20),
          const _InfoLabel('THE LADDER'),
          const SizedBox(height: 10),
          const _TierRow(
            tier: RankTier.iron,
            caption: 'Just starting out',
          ),
          const _TierRow(tier: RankTier.bronze, caption: 'Beginner'),
          const _TierRow(tier: RankTier.silver, caption: 'Novice'),
          const _TierRow(tier: RankTier.gold, caption: 'Intermediate'),
          const _TierRow(tier: RankTier.platinum, caption: 'Strong'),
          const _TierRow(tier: RankTier.diamond, caption: 'Advanced'),
          const _TierRow(tier: RankTier.master, caption: 'Very advanced'),
          const _TierRow(tier: RankTier.grandmaster, caption: 'Elite'),
          const _TierRow(
            tier: RankTier.alpha,
            caption: 'Top 1 % — no divisions',
          ),
          const SizedBox(height: 22),
          const _InfoLabel('HOW IT IS CALCULATED'),
          const SizedBox(height: 10),
          const _InfoBullet(
            'Only completed working sets count. Warm-ups, drop sets and '
            'invalid reps are ignored.',
          ),
          const _InfoBullet(
            'Each set is converted to an estimated 1RM, then compared with '
            'the Strength Level table for your sex and exact bodyweight.',
          ),
          const _InfoBullet(
            'An exercise uses the best set from your last 3 sessions, up to '
            '12 weeks back. It never drops below 85 % of your all-time best, '
            'so a break does not cost you a rank.',
          ),
          const _InfoBullet(
            'A sub-muscle is a weighted average of its exercises (more sets = '
            'more influence, capped at 12 sets).',
          ),
          const _InfoBullet(
            'A muscle group averages its sub-muscles and the overall rank '
            'averages all six groups equally.',
          ),
          const _InfoBullet(
            'The overall rank unlocks at $kRankGlobalUnlockCount ranked '
            'exercises. Everything is calculated from your own history — '
            'there is no leaderboard.',
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: const Text(
              'Thresholds come from Strength Level\'s public by-bodyweight '
              'tables for men and women. Their five published levels (5th, '
              '20th, 50th, 80th and 95th percentile) anchor the rank '
              'boundaries; divisions are interpolated between them. Machine '
              'leverage varies between gyms.',
              style: TextStyle(
                fontSize: 11,
                height: 1.5,
                color: AppTheme.textMuted,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _InfoLabel extends StatelessWidget {
  const _InfoLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: AppTheme.textMuted,
      ),
    );
  }
}

class _TierRow extends StatelessWidget {
  const _TierRow({required this.tier, required this.caption});

  final RankTier tier;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tier.color,
              boxShadow: [
                BoxShadow(
                  color: tier.color.withValues(alpha: 0.45),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 130,
            child: Text(
              tier.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: tier.color,
              ),
            ),
          ),
          Expanded(
            child: Text(
              caption,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBullet extends StatelessWidget {
  const _InfoBullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppTheme.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
