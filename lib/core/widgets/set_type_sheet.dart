import 'package:flutter/material.dart';

import '../../core/set_type.dart';
import '../theme.dart';

/// Zobrazi dolni menu pro vyber typu serie (normal/W/F/D).
///
/// [onTypeSelected] zavola s novym typem, kdyz uzivatel klikne na polozku.
/// [onRemoveSet] je volitelny – pokud je zadany, prida do menu polozku "Remove set".
Future<void> showSetTypeSheet(
  BuildContext context, {
  required String currentType,
  required ValueChanged<String> onTypeSelected,
  VoidCallback? onRemoveSet,
}) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          for (final entry in SetType.labels.entries)
            ListTile(
              leading: entry.key == currentType
                  ? const Icon(
                      Icons.check_circle_rounded,
                      color: AppTheme.accentBright,
                    )
                  : const SizedBox(width: 24),
              title: Text(
                entry.value,
                style: TextStyle(
                  fontWeight: entry.key == currentType
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: entry.key == currentType
                      ? AppTheme.accentBright
                      : null,
                ),
              ),
              onTap: () {
                onTypeSelected(entry.key);
                Navigator.pop(sheetContext);
              },
            ),
          if (onRemoveSet != null) ...[
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: AppTheme.danger,
              ),
              title: const Text(
                'Remove set',
                style: TextStyle(color: AppTheme.danger),
              ),
              onTap: () {
                onRemoveSet();
                Navigator.pop(sheetContext);
              },
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
