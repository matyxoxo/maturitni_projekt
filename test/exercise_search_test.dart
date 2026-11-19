import 'package:alphalift/features/exercises/exercise_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Exercise _exercise(
  String name, {
  String group = 'Biceps',
  String sub = 'Biceps',
  String? equipment = 'Cable',
}) =>
    Exercise(
      id: name,
      name: name,
      exerciseType: 'weight_reps',
      equipment: equipment,
      gifUrl: null,
      muscleGroup: group,
      subMuscleGroup: sub,
    );

void main() {
  test('isRanked vraci true jen pro cviky se standardem', () {
    expect(_exercise('Barbell Bench Press').isRanked, isTrue);
    expect(_exercise('Cable Curl').isRanked, isTrue);
    expect(_exercise('Vymysleny cvik 123').isRanked, isFalse);
  });

  test('pri hledani "biceps" jsou rankovane cviky nahore', () {
    final ranked = _exercise('Cable Curl');
    final unranked = _exercise('Cable Biceps Thing');

    final result = filterExercises([unranked, ranked], query: 'biceps');

    expect(result.first.name, 'Cable Curl');
    expect(result.first.isRanked, isTrue);
  });

  test('ranked bonus neprebije presnou shodu nazvu', () {
    final exact = _exercise('Curl', group: 'Biceps', sub: 'Biceps');
    final rankedPartial = _exercise('Cable Curl');

    final result = filterExercises([rankedPartial, exact], query: 'curl');

    expect(result.first.name, 'Curl');
    expect(result.first.isRanked, isFalse);
  });
}
