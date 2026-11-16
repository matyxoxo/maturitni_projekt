import 'package:flutter/material.dart';

import '../theme.dart';

/// Maly nahled cviku (gif nebo placeholder ikona).
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
    final radius = BorderRadius.circular(size >= 40 ? 10 : 8);
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: radius,
      ),
      child: Icon(
        Icons.fitness_center_rounded,
        size: size * 0.45,
        color: AppTheme.textMuted,
      ),
    );

    if (gifUrl == null) return placeholder;

    return ClipRRect(
      borderRadius: radius,
      child: Image.network(
        gifUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return placeholder;
        },
      ),
    );
  }
}
