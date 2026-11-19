import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/constants/constants.dart';
import 'package:fide/models/hardcoded_string.dart';
import 'package:fide/models/hardcoded_string_role.dart';
import 'package:fide/models/locale_number.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/models/string_review.dart';
import 'package:fide/widgets/check_list_tile.dart';
import 'package:fide/widgets/compact_text_button.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/primary_button.dart';
import 'package:fide/widgets/quick_fix_icon.dart';
import 'package:fide/widgets/section_title.dart';
import 'package:fide/widgets/status_tone_style.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

/// The body of the dialog showing a project's hardcoded strings grouped
/// by role, each string with
/// the use that decided it and a link to its code, and each group with
/// its actions: FIDE's fixes matching the role for the strings they can
/// take, checked one by one, and the AI for the others, such as
/// fragments or strings without a `BuildContext`.
///
/// What each fix makes of each string is worked out once when the dialog
/// opens, and only the rows in view are built, so checking a string stays
/// quick with thousands of them.
class StringReviewDialog extends StatefulWidget {
  /// Creates the body reviewing [review], opening a string's code
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
  }) {
    final total = fcheck.HardcodedStringRole.values.fold(
      0,
      (sum, role) => sum + review.withRole(role).length,
    );
    return MessageBox.showDetails<StringReviewChoice>(
      context,
      title: Text('Hardcoded strings (${total.localized})'),
      content: StringReviewDialog(review: review, onOpen: onOpen),
      scrollable: false,
    );
  }
}

class _StringReviewDialogState extends State<StringReviewDialog> {
  /// Marks the strings and the action left to the AI.

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
        ...strings.where(_isFixable),
  };

  /// What the fixes of its group make of each string, worked out once.
  late final Map<HardcodedString, StringVerdict> _verdicts = widget.review
      .verdictsOn(_byRole.values.expand((strings) => strings));

  @override
  Widget build(BuildContext context) {
    // One item per heading, string and row of actions, built as they
    // scroll into view
    final items = <WidgetBuilder>[
      (context) => Text(
        'Grouped by how the code uses each string, shown under it. '
        'FIDE fixes the checked strings at once; the AI fixes the '
        'others. Open a string to check it in the code.',
        style: AppTextStyle.secondary(context),
      ),
      for (final MapEntry(key: role, value: strings) in _byRole.entries) ...[
        (context) => _heading(context, role, strings),
        for (final string in strings)
          (context) => _spaced(_row(context, string)),
        (_ /*context*/) => _spaced(_actions(role, strings)),
      ],
    ];
    return SizedBox(
      width: AppSize.issueDetailsWidth,
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: items.length,
        itemBuilder: (context, index) => items[index](context),
      ),
    );
  }

  /// The button applying [fix], or the AI when null, to [strings].
  Widget _action({
    required IconData icon,
    required String label,
    required StringFix? fix,
    required List<HardcodedString> strings,
  }) => PrimaryButton(
    icon: icon,
    label: '$label (${strings.length.localized})',
    onPressed: strings.isEmpty
        ? null
        : () => Navigator.of(context).pop((fix: fix, strings: strings)),
  );

  /// The actions that can take some of [strings] of [role]: each fix of
  /// the group on the checked strings it can take, and the AI on those no
  /// fix can.
  Widget _actions(
    fcheck.HardcodedStringRole role,
    List<HardcodedString> strings,
  ) {
    final forAi = strings.where((string) => !_isFixable(string)).toList();
    return Wrap(
      spacing: AppSpacing.medium,
      runSpacing: AppSpacing.medium,
      children: [
        for (final fix in StringReview.fixesFor(role))
          if (strings.any((string) => _verdicts[string]!.canTake(fix)))
            _action(
              icon: fix.quickFix.icon,
              label: fix.label,
              fix: fix,
              strings: [
                for (final string in strings)
                  if (_selected.contains(string) &&
                      _verdicts[string]!.canTake(fix))
                    string,
              ],
            ),
        if (forAi.isNotEmpty)
          _action(
            icon: AppIcon.ai,
            label: 'Fix with AI',
            fix: null,
            strings: forAi,
          ),
      ],
    );
  }

  /// The heading of the group of [strings] of [role]: its title with the
  /// buttons checking them all or none, and why they are in it.
  Widget _heading(
    BuildContext context,
    fcheck.HardcodedStringRole role,
    List<HardcodedString> strings,
  ) => Padding(
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
              onPressed: () =>
                  setState(() => _selected.addAll(strings.where(_isFixable))),
            ),
            CompactTextButton(
              label: 'Select none',
              onPressed: () => setState(() => _selected.removeAll(strings)),
            ),
          ],
        ),
        Text(role.explanation, style: AppTextStyle.secondary(context)),
      ],
    ),
  );

  /// Whether a fix of its group can take [string]; the AI fixes the
  /// others.
  bool _isFixable(HardcodedString string) => _verdicts[string]!.isFixable;

  /// [string]: its checkbox when a fix of its group can take it, else the
  /// AI's mark, its text, the use that decided its role, why no fix of the
  /// group can take it, and a link to its code.
  Widget _row(BuildContext context, HardcodedString string) {
    final secondary = AppTextStyle.secondary(context);
    final verdict = _verdicts[string]!;
    final isFixable = verdict.isFixable;
    // Reasons only where no fix of the group can take the string
    final reasons = isFixable ? const <String>[] : verdict.reasons;
    final subtitle = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (string.evidence.isNotEmpty) Text(string.evidence, style: secondary),
        for (final reason in reasons)
          Text(
            reason,
            style: secondary.copyWith(
              color: StatusTone.warning.readableIn(
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
        leading: const Icon(AppIcon.ai),
        title: title,
        subtitle: subtitle,
        trailing: open,
      );
    }
    return CheckListTile(
      value: _selected.contains(string),
      onChanged: (checked) => setState(
        () => checked ? _selected.add(string) : _selected.remove(string),
      ),
      title: title,
      subtitle: subtitle,
      trailing: open,
    );
  }

  /// [child] one small gap under the item before it in its group.
  Widget _spaced(Widget child) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.tiny),
    child: child,
  );
}
