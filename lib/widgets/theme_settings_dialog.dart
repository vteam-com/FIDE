import 'package:fide/models/constants.dart';
import 'package:flutter/material.dart';

/// Opens a shared settings dialog for selecting the app theme mode.
Future<void> showThemeSettingsDialog(
  BuildContext context,
  ValueChanged<ThemeMode> onThemeChanged,
) async {
  await showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Theme'),
            const SizedBox(height: AppSpacing.medium),
            ListTile(
              leading: const Icon(Icons.brightness_auto),
              title: const Text('System'),
              onTap: () {
                onThemeChanged(ThemeMode.system);
                Navigator.of(dialogContext).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.brightness_5),
              title: const Text('Light'),
              onTap: () {
                onThemeChanged(ThemeMode.light);
                Navigator.of(dialogContext).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.brightness_2),
              title: const Text('Dark'),
              onTap: () {
                onThemeChanged(ThemeMode.dark);
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}
