import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/constants/constants.dart';
import 'package:fide/models/hardcoded_string.dart';
import 'package:fide/models/hardcoded_string_role.dart';
import 'package:fide/models/locale_number.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/models/string_review.dart';
import 'package:fide/theme/app_theme.dart';
import 'package:fide/widgets/compact_text_button.dart';
import 'package:fide/widgets/quick_fix_icon.dart';
import 'package:fide/widgets/section_title.dart';
import 'package:fide/widgets/status_tone_style.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

/// Shows a project's hardcoded strings grouped by role, each string with
/// the use that decided it and a link to its code, and each group with
/// its actions: FIDE's fixes matching the role for the strings they can
/// take, checked one by one, and the AI for the others, such as
/// fragments or strings without a `BuildContext`.
class StringReviewDialog extends StatefulWidget {
  /// Creates the dialog reviewing [review], opening a string's code
  /// through [onOpen].
  const StringReviewDialog({
    super.key,
    required this.review,
    required this.onOpen,
  });

  /// Opens a string's code in the editor, once the dialog is closed.
  final void Function(HardcodedString) onOpen;

  /// The strings and what each fix would do.
  final StringReview review;

  @override
  State<StringReviewDialog> createState() => _StringReviewDialogState();

  /// Shows the dialog; resolves to the picked fix and strings, null when
  /// closed or left to open a string's code with [onOpen].
  static Future<StringReviewChoice?> show(
    BuildContext context,
    StringReview review, {
    required void Function(HardcodedString) onOpen,
  }) => showDialog<StringReviewChoice>(
    context: context,
    builder: (_ /*context*/) =>
        StringReviewDialog(review: review, onOpen: onOpen),
  );
}

class _StringReviewDialogState extends State<StringReviewDialog> {
  /// Marks the strings and the action left to the AI.
  static const IconData _aiIcon = Icons.auto_fix_high;

  /// Strings by role, the empty roles left out.
  late final Map<fcheck.HardcodedStringRole, List<HardcodedString>> _byRole = {
    for (final role in fcheck.HardcodedStringRole.values)
      if (widget.review.withRole(role) case final strings
          when strings.isNotEmpty)
        role: strings,
  };

  /// Checked strings: those a fix of their group can take, but those of
  /// unknown role.
  late final Set<HardcodedString> _selected = {
    for (final MapEntry(key: role, value: strings) in _byRole.entries)
      if (role != fcheck.HardcodedStringRole.unknown)
        ...strings.where((string) => _isFixable(role, string)),
  };

  @override
  Widget build(BuildContext context) {
    final total = _byRole.values.fold(0, (sum, list) => sum + list.length);
    return AlertDialog(
      title: Text('Hardcoded strings (${total.localized})'),
      content: SizedBox(
        width: AppSize.issueDetailsWidth,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              'Grouped by how the code uses each string, shown under it. '
              'FIDE fixes the checked strings at once; the AI fixes the '
              'others. Open a string to check it in the code.',
              style: AppTextStyle.secondary(context),
            ),
            for (final MapEntry(key: role, value: strings) in _byRole.entries)
              _section(context, role, strings),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  /// The button applying [fix], or the AI when null, to [strings].
  Widget _action({
    required IconData icon,
    required String label,
    required StringFix? fix,
    required List<HardcodedString> strings,
  }) => FilledButton.icon(
    icon: Icon(icon),
    label: Text('$label (${strings.length.localized})'),
    onPressed: strings.isEmpty
        ? null
        : () => Navigator.of(context).pop((fix: fix, strings: strings)),
  );

  /// Whether a fix of the group of [role] can take [string]; the AI fixes
  /// the others.
  bool _isFixable(fcheck.HardcodedStringRole role, HardcodedString string) =>
      StringReview.fixesFor(role)
          .any((fix) => widget.review.whyNot(fix, string) == null);

  /// [string] in the group of [role]: its checkbox when a fix can take it,
  /// else the AI's mark, its text, the use that decided its role, why a
  /// fix of the group cannot take it, and a link to its code.
  Widget _row(
    BuildContext context,
    fcheck.HardcodedStringRole role,
    HardcodedString string,
  ) {
    final secondary = AppTextStyle.secondary(context);
    final isFixable = _isFixable(role, string);
    // Reasons only where no fix of the group can take the string
    final reasons = [
      if (!isFixable)
        for (final fix in StringReview.fixesFor(role))
          if (widget.review.whyNot(fix, string) case final reason?)
            '${fix.label} $reason',
    ];
    final subtitle = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (string.evidence.isNotEmpty) Text(string.evidence, style: secondary),
        for (final reason in reasons)
          Text(
            reason,
            style: secondary.copyWith(
              color: AppTheme.readable(
                StatusTone.warning.color,
                Theme.of(context).colorScheme,
              ),
            ),
          ),
      ],
    );
    final open = CompactTextButton(
      icon: Icons.open_in_new,
      label: '${p.basename(string.path)}:${string.line}',
      onPressed: () {
        Navigator.of(context).pop();
        widget.onOpen(string);
      },
    );
    final title = Text('"${string.message.text}"');
    if (!isFixable) {
      return ListTile(
        dense: true,
        leading: const Icon(_aiIcon),
        title: title,
        subtitle: subtitle,
        trailing: open,
      );
    }
    return CheckboxListTile(
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      value: _selected.contains(string),
      onChanged: (checked) => setState(
        () =>
            checked == true ? _selected.add(string) : _selected.remove(string),
      ),
      title: title,
      subtitle: subtitle,
      secondary: open,
    );
  }

  /// The group of [strings] of [role]: its title, why, its strings and
  /// the actions that can take some of them.
  Widget _section(
    BuildContext context,
    fcheck.HardcodedStringRole role,
    List<HardcodedString> strings,
  ) {
    List<HardcodedString> checked(bool Function(HardcodedString) canTake) => [
      for (final string in strings)
        if (_selected.contains(string) && canTake(string)) string,
    ];
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.tiny,
        children: [
          Row(
            children: [
              Expanded(
                child: SectionTitle(
                  '${role.label} (${strings.length.localized})',
                ),
              ),
              CompactTextButton(
                label: 'Select all',
                onPressed: () => setState(
                  () => _selected.addAll(
                    strings.where((string) => _isFixable(role, string)),
                  ),
                ),
              ),
              CompactTextButton(
                label: 'Select none',
                onPressed: () => setState(() => _selected.removeAll(strings)),
              ),
            ],
          ),
          Text(role.explanation, style: AppTextStyle.secondary(context)),
          for (final string in strings) _row(context, role, string),
          Wrap(
            spacing: AppSpacing.medium,
            runSpacing: AppSpacing.medium,
            children: [
              for (final fix in StringReview.fixesFor(role))
                if (strings.any(
                  (string) => widget.review.whyNot(fix, string) == null,
                ))
                  _action(
                    icon: fix.quickFix.icon,
                    label: fix.label,
                    fix: fix,
                    strings: checked(
                      (string) => widget.review.whyNot(fix, string) == null,
                    ),
                  ),
              if (strings.where((string) => !_isFixable(role, string))
                  case final forAi when forAi.isNotEmpty)
                _action(
                  icon: _aiIcon,
                  label: 'Fix with AI',
                  fix: null,
                  strings: forAi.toList(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
