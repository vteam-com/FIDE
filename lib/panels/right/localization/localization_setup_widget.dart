import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/action_card.dart';
import 'package:fide/widgets/panel_scroll_view.dart';
import 'package:fide/widgets/primary_button.dart';
import 'package:fide/widgets/section_title.dart';
import 'package:material_ui/material_ui.dart';

/// The Localize panel of a project without localization: what Initialize
/// sets up, then how to use the strings it generates. Laid out as the
/// partly set up project's checklist is, so both read alike.
class LocalizationSetupWidget extends StatelessWidget {
  /// Creates the setup view, its button calling [onInitializeLocalization].
  const LocalizationSetupWidget({
    super.key,
    required this.onInitializeLocalization,
  });

  /// Sets localization up.
  final VoidCallback onInitializeLocalization;

  @override
  Widget build(BuildContext context) {
    return PanelScrollView(
      children: [
        const SectionTitle('Setup Localization'),
        Text(
          'Your Flutter project needs localization setup.',
          style: AppTextStyle.label,
        ),
        initializeCard(onInitializeLocalization),
        const SectionTitle('Next Steps'),
        Text(
          'After setup, use AppLocalizations.of(context) to display localized strings in your widgets.',
          style: AppTextStyle.label,
        ),
      ],
    );
  }

  /// The card setting localization up, calling [onPressed]: shown here
  /// and as the next step of a project missing its ARB files, alike.
  static Widget initializeCard(VoidCallback onPressed) {
    return ActionCard(
      title: 'Initialize Localization',
      icon: AppIcon.fix,
      description: 'Automatically configure everything needed for localization',
      steps: const [
        'Add flutter_localizations & intl packages',
        'Create l10n directory and ARB files',
        'Generate AppLocalizations class',
      ],
      action: PrimaryButton(
        icon: AppIcon.fix,
        label: 'Initialize',
        onPressed: onPressed,
      ),
    );
  }
}
