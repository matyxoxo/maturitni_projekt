import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'active_workout_provider.dart';

final recentWorkoutsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return [];
  return Supabase.instance.client
      .from('workouts')
      .select('workout_id, workout_title, created_at, total_volume_kg')
      .eq('user_id', userId)
      .order('created_at', ascending: false)
      .limit(10);
});

class WorkoutScreen extends ConsumerWidget {
  const WorkoutScreen({super.key});

  void _startEmptyWorkout(BuildContext context, WidgetRef ref) {
    ref.read(activeWorkoutProvider.notifier).reset();
    context.push('/workout/active');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Workout')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ActionCard(
            icon: Icons.play_arrow,
            title: 'Start empty workout',
            subtitle: 'Build your session from scratch',
            onTap: () => _startEmptyWorkout(context, ref),
          ),
          _ActionCard(
            icon: Icons.playlist_add,
            title: 'New routine',
            subtitle: 'Save a reusable template',
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Routines coming soon.')),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Recent workouts',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const _RecentWorkouts(),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _RecentWorkouts extends ConsumerWidget {
  const _RecentWorkouts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutsAsync = ref.watch(recentWorkoutsProvider);

    return workoutsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Text('Error: $err'),
      data: (workouts) {
        if (workouts.isEmpty) {
          return Text(
            'No workouts yet. Start your first one!',
            style: TextStyle(color: Colors.grey.shade400),
          );
        }
        return Column(
          children: [
            for (final workout in workouts)
              ListTile(
                leading: const Icon(Icons.fitness_center),
                title: Text(workout['workout_title'] as String),
                subtitle: Text(
                  [
                    if (workout['total_volume_kg'] != null)
                      '${(workout['total_volume_kg'] as num).toStringAsFixed(0)} kg',
                    DateTime.parse(workout['created_at'] as String)
                        .toLocal()
                        .toString()
                        .substring(0, 16),
                  ].join(' • '),
                ),
              ),
          ],
        );
      },
    );
  }
}
