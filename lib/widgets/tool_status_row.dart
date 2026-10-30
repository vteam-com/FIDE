import 'package:fide/constants/constants.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/status_indicator.dart';
import 'package:flutter/material.dart';

/// Whether a required tool (Flutter, Git...) was found, with its version,
/// or an Install button opening [installInstructions] when it wasn't.
class ToolStatusRow extends StatelessWidget {
  /// Creates the status of tool [name].
  const ToolStatusRow({
    super.key,
    required this.name,
    required this.available,
    required this.version,
    required this.installInstructions,
  });

  /// Whether the tool was found.
  final bool available;

  /// How to install the tool, shown from the Install button.
  final String installInstructions;

  /// Tool name, e.g. `Git`.
  final String name;

  /// Detected version, shown when [available]; null when unknown.
  final String? version;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.medium),
      child: Row(
        spacing: AppSpacing.medium,
        children: [
          StatusIndicator.tone(
            available ? StatusTone.success : StatusTone.error,
            label: '$name: ${available ? version ?? 'Unknown' : 'Not Found'}',
          ),
          if (!available)
            TextButton(
              onPressed: () => _showInstructions(context),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(
                  AppSize.compactTextButtonMinWidth,
                  AppSize.compactButtonHeight,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Install',
                style: TextStyle(fontSize: AppFontSize.caption),
              ),
            ),
        ],
      ),
    );
  }

  /// Shows [installInstructions] in a dialog.
  void _showInstructions(BuildContext context) {
    MessageBox.showDetails(
      context,
      title: Text('Install $name'),
      content: Text(installInstructions),
    );
  }
}
