import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/exercise_types.dart';
import '../../core/format.dart';
import '../home/home_repository.dart';

class WorkoutDetailScreen extends ConsumerWidget {
  const WorkoutDetailScreen({super.key, required this.workoutId});

  final String workoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(workoutDetailProvider(workoutId));

    return Scaffold(
      appBar: AppBar(title: const Text('Workout')),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (detail) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  child: Text(
                    detail.username.isEmpty
                        ? '?'
                        : detail.username[0].toUpperCase(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail.username,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        timeAgo(detail.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              detail.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(width: 4),
                Text(
                  detail.durationSeconds != null
                      ? formatDuration(detail.durationSeconds!)
                      : '--:--',
                  style: TextStyle(color: Colors.grey.shade400),
                ),
                const SizedBox(width: 16),
                Icon(Icons.fitness_center, size: 16, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(
                  formatVolume(detail.totalVolumeKg),
                  style: TextStyle(color: Colors.grey.shade400),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            for (final exercise in detail.exercises) ...[
              _ExerciseDetailSection(exercise: exercise),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExerciseDetailSection extends StatelessWidget {
  const _ExerciseDetailSection({required this.exercise});

  final WorkoutDetailExercise exercise;

  @override
  Widget build(BuildContext context) {
    final config = configForExerciseType(exercise.exerciseType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _GifBox(gifUrl: exercise.gifUrl, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                exercise.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _SetTableHeader(config: config),
        for (final set in exercise.sets)
          _SetDetailRow(set: set, config: config),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _SetTableHeader extends StatelessWidget {
  const _SetTableHeader({required this.config});

  final ExerciseInputConfig config;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: Colors.grey.shade500,
      letterSpacing: 0.5,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Center(child: Text('SET', style: style)),
          ),
          const SizedBox(width: 8),
          if (config.showWeight)
            SizedBox(
              width: 74,
              child: Center(child: Text(config.weightLabel, style: style)),
            ),
          if (config.showReps)
            SizedBox(
              width: 64,
              child: Center(child: Text('REPS', style: style)),
            ),
          if (config.showDuration)
            SizedBox(
              width: 64,
              child: Center(child: Text('TIME', style: style)),
            ),
          if (config.showDistance)
            SizedBox(
              width: 64,
              child: Center(child: Text('KM', style: style)),
            ),
          const Spacer(),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _SetDetailRow extends StatelessWidget {
  const _SetDetailRow({required this.set, required this.config});

  final WorkoutSetDetail set;
  final ExerciseInputConfig config;

  static const _setTypeLabels = <String, String>{
    'normal': '',
    'warmup': 'W',
    'failure': 'F',
    'dropSet': 'D',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Center(
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade600),
                ),
                child: Text(
                  _setTypeLabels[set.setType] ?? '${set.setNumber}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (config.showWeight)
            SizedBox(
              width: 74,
              child: Center(
                child: Text(
                  set.weightKg != null ? '${set.weightKg}' : '–',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          if (config.showReps)
            SizedBox(
              width: 64,
              child: Center(
                child: Text(
                  set.repsCount != null ? '${set.repsCount}' : '–',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          if (config.showDuration)
            SizedBox(
              width: 64,
              child: Center(
                child: Text(
                  set.durationSeconds != null
                      ? '${set.durationSeconds}s'
                      : '–',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          if (config.showDistance)
            SizedBox(
              width: 64,
              child: Center(
                child: Text(
                  set.distanceMeters != null
                      ? '${set.distanceMeters}m'
                      : '–',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          const Spacer(),
          SizedBox(
            width: 40,
            child: Icon(
              set.isCompleted
                  ? Icons.check_circle
                  : Icons.check_circle_outline,
              size: 22,
              color: set.isCompleted
                  ? Colors.green.shade300
                  : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GifBox extends StatelessWidget {
  const _GifBox({required this.gifUrl, this.size = 48});

  final String? gifUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (gifUrl == null) {
      return Icon(Icons.fitness_center, size: size);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        gifUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Icon(Icons.fitness_center, size: size),
      ),
    );
  }
}
