import 'package:flutter/material.dart';

import '../../core/set_type.dart';

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
          for (final entry in SetType.labels.entries)
            ListTile(
              leading: entry.key == currentType
                  ? const Icon(Icons.check)
                  : const SizedBox(width: 24),
              title: Text(entry.value),
              onTap: () {
                onTypeSelected(entry.key);
                Navigator.pop(sheetContext);
              },
            ),
          if (onRemoveSet != null) ...[
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.delete_outline, color: Colors.red.shade400),
              title: Text(
                'Remove set',
                style: TextStyle(color: Colors.red.shade400),
              ),
              onTap: () {
                onRemoveSet();
                Navigator.pop(sheetContext);
              },
            ),
          ],
        ],
      ),
    ),
  );
}
