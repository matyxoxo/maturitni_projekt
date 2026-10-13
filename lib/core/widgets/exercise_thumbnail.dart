import 'package:flutter/material.dart';

class ExerciseThumbnail extends StatelessWidget {
  const ExerciseThumbnail({
    super.key,
    required this.gifUrl,
    this.size = 48,
  });

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
