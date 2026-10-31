import 'package:fcheck/fcheck.dart' as fcheck;

/// How FIDE presents a [fcheck.HardcodedStringRole] to the user and the AI.
extension HardcodedStringRoleText on fcheck.HardcodedStringRole {
  /// What the AI is asked to do with a string of this role.
  String get aiInstruction => _texts.aiInstruction;

  /// Why strings of this role get their fix, under the section title.
  String get explanation => _texts.explanation;

  /// The role's section title.
  String get label => _texts.label;

  /// The role's texts, written together per role.
  ({String label, String explanation, String aiInstruction}) get _texts =>
      switch (this) {
        fcheck.HardcodedStringRole.presentation => (
          label: 'Presentation',
          explanation:
              'We think users read these, so they should be translated.',
          aiInstruction:
              'localize it, getting a BuildContext where it is shown if '
              'needed',
        ),
        fcheck.HardcodedStringRole.data => (
          label: 'Data',
          explanation:
              'We think the code compares or looks these up; translating '
              'them would break it, so they should be constants.',
          aiInstruction:
              "make it a constant of DataKeys, the class holding the "
              "project's string constants",
        ),
        fcheck.HardcodedStringRole.fragment => (
          label: 'Fragments',
          explanation:
              'We think these are shown only inside another message; '
              'translate the whole message instead, one per caller.',
          aiInstruction:
              'have each caller pass one whole localized message instead',
        ),
        fcheck.HardcodedStringRole.unknown => (
          label: 'Unknown',
          explanation:
              'We could not tell how these are used: check each one and '
              'pick its fix.',
          aiInstruction:
              'localize it if users read it, otherwise make it a constant',
        ),
      };
}
