import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import 'rank_engine.dart';
import 'rank_model.dart';
import 'rank_repository.dart';
import 'rank_widgets.dart';

/// Detail jednoho podsvalu – seznam cviků s rankem.
class RankMuscleScreen extends ConsumerWidget {
  const RankMuscleScreen({
    super.key,
    required this.groupName,
    required this.muscleName,
  });

  final String groupName;
  final String muscleName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(rankReportProvider);

    return Scaffold(
      appBar: AppBar(title: Text(muscleName)),
      body: report.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load $muscleName.\n$error',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppTheme.textMuted,
              ),
            ),
          ),
        ),
        data: (data) {
          final muscle = data.muscleByName(groupName, muscleName);
          if (muscle == null) {
            return const _EmptyMuscle();
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
            children: [
              _MuscleHeader(groupName: groupName, muscle: muscle),
              const SizedBox(height: 20),
              if (muscle.exercises.isEmpty)
                const _EmptyMuscle()
              else ...[
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Exercises',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                    Text(
                      '${muscle.exercises.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final exercise in muscle.exercises) ...[
                  _ExerciseCard(exercise: exercise),
                  const SizedBox(height: 10),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MuscleHeader extends StatelessWidget {
  const _MuscleHeader({required this.groupName, required this.muscle});

  final String groupName;
  final RankMuscle muscle;

  @override
  Widget build(BuildContext context) {
    final rank = muscle.rank;
    final color = rank?.tier.color ?? AppTheme.outline;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: AppTheme.heroGradient,
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        boxShadow: rank == null
            ? null
            : [
                BoxShadow(
                  color: color.withValues(alpha: 0.1),
                  blurRadius: 36,
                  offset: const Offset(0, 12),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RankBadge(rank: rank, size: 72),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      groupName.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.3,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      muscle.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      rank?.label ?? 'No rank yet',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (rank != null) ...[
            const SizedBox(height: 18),
            RankProgressBar(rank: rank),
            const SizedBox(height: 10),
            Text(
              'Weighted average of ${muscle.exercises.length} '
              '${muscle.exercises.length == 1 ? 'exercise' : 'exercises'} · '
              'more sets = more influence',
              style: const TextStyle(
                fontSize: 11,
                height: 1.4,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.exercise});

  final RankedExercise exercise;

  @override
  Widget build(BuildContext context) {
    final rank = exercise.rank;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
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
                      exercise.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _Chip(text: '${exercise.sets12w} sets / 12 w'),
                        if (exercise.perHand)
                          const _Chip(text: 'weight per dumbbell'),
                        if (!exercise.hasFreshData)
                          const _Chip(text: 'rank kept from all-time best'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              RankPill(rank: rank),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'BEST SET',
                  value:
                      '${formatRankKg(exercise.bestWeightKg)} kg × ${exercise.bestReps}',
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'e1RM',
                  value: '${formatRankKg(exercise.e1rmKg)} kg',
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'ALL-TIME',
                  value: '${formatRankKg(exercise.allTimeE1rmKg)} kg',
                ),
              ),
            ],
          ),
          if (exercise.nextRankLabel != null &&
              exercise.nextE1rmKg != null) ...[
            const SizedBox(height: 16),
            RankProgressBar(rank: rank, showLabel: false),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${exercise.nextRankLabel} at '
                    '${formatRankKg(exercise.nextE1rmKg!)} kg e1RM',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
                Text(
                  '${(rank.progress * 100).round()} %',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: rank.tier.color,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.9,
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
      ),
    );
  }
}

class _EmptyMuscle extends StatelessWidget {
  const _EmptyMuscle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.surface,
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: const Icon(
              Icons.fitness_center_rounded,
              size: 26,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No ranked sets yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Log a ranked exercise for this muscle and its rank will appear '
            'right after you finish the workout.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
