import 'package:fide/constants/constants.dart';
import 'package:fide/providers/markdown_preview_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notifier_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Markdown files show as text until the user chooses', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(markdownPreviewProvider), isFalse);
  });

  test('setPreview shows and saves the choice', () async {
    final notifier = MarkdownPreviewNotifier(SharedPreferences.getInstance());

    await notifier.setPreview(true);

    expect(stateOf(notifier), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(PrefKeys.markdownPreview), isTrue);
  });

  test('load restores the saved choice', () async {
    SharedPreferences.setMockInitialValues({PrefKeys.markdownPreview: true});
    final restored = MarkdownPreviewNotifier(SharedPreferences.getInstance());

    await restored.load();

    expect(stateOf(restored), isTrue);
  });
}
