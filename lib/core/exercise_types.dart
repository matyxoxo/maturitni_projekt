class ExerciseInputConfig {
  const ExerciseInputConfig({
    required this.showWeight,
    required this.showReps,
    required this.showDuration,
    required this.showDistance,
    required this.weightLabel,
  });

  final bool showWeight;
  final bool showReps;
  final bool showDuration;
  final bool showDistance;
  final String weightLabel;
}

ExerciseInputConfig configForExerciseType(String type) {
  switch (type) {
    case 'bodyweight_reps':
      return const ExerciseInputConfig(
        showWeight: false,
        showReps: true,
        showDuration: false,
        showDistance: false,
        weightLabel: 'KG',
      );
    case 'weighted_bodyweight':
      return const ExerciseInputConfig(
        showWeight: true,
        showReps: true,
        showDuration: false,
        showDistance: false,
        weightLabel: 'ADDED',
      );
    case 'assisted_bodyweight':
      return const ExerciseInputConfig(
        showWeight: true,
        showReps: true,
        showDuration: false,
        showDistance: false,
        weightLabel: 'KG',
      );
    case 'duration':
      return const ExerciseInputConfig(
        showWeight: false,
        showReps: false,
        showDuration: true,
        showDistance: false,
        weightLabel: 'KG',
      );
    case 'distance_duration':
      return const ExerciseInputConfig(
        showWeight: false,
        showReps: false,
        showDuration: true,
        showDistance: true,
        weightLabel: 'KG',
      );
    case 'weight_reps':
    default:
      return const ExerciseInputConfig(
        showWeight: true,
        showReps: true,
        showDuration: false,
        showDistance: false,
        weightLabel: 'KG',
      );
  }
}
