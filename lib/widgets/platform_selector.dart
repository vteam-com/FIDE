import 'package:fide/constants/constants.dart';
import 'package:fide/models/flutter_platform.dart';
import 'package:fide/widgets/choice_buttons.dart';
import 'package:fide/widgets/platform_icon.dart';
import 'package:material_ui/material_ui.dart';

/// Picks the platform the Execute panel builds and runs for, as every
/// one-of-N choice is picked: [ChoiceButtons], one per platform, those
/// the project doesn't configure dimmed.
class PlatformSelector extends StatelessWidget {
  /// Creates the picker, [selectedPlatform] highlighted.
  const PlatformSelector({
    super.key,
    required this.supportedPlatforms,
    required this.selectedPlatform,
    required this.onPlatformSelected,
  });

  /// Called with the platform picked.
  final ValueChanged<FlutterPlatform> onPlatformSelected;

  /// The platform highlighted.
  final FlutterPlatform selectedPlatform;

  /// The platforms the project configures.
  final Set<FlutterPlatform> supportedPlatforms;

  @override
  Widget build(BuildContext context) {
    return ChoiceButtons<FlutterPlatform>(
      values: FlutterPlatform.values,
      selected: selectedPlatform,
      icon: (platform) => PlatformIcon(
        platform: platform,
        size: AppIconSize.small,
        isSupported: supportedPlatforms.contains(platform),
        isSelected: platform == selectedPlatform,
      ),
      label: (platform) => supportedPlatforms.contains(platform)
          ? platform.displayName
          : '${platform.displayName} (not configured)',
      onSelected: onPlatformSelected,
    );
  }
}
