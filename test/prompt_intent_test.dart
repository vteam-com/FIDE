import 'package:fide/models/prompt_intent.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a request starting with a change verb asks for a change', () {
    for (final prompt in [
      'fix 1 and 3',
      'Add a reset button',
      'rename _scrollToEnd to _followLatest',
      'please localize this screen',
      'Can you fix the overflow?',
      "let's extract a widget",
      'Now, update the README',
      'run flutter pub upgrade google_sign_in_ios',
      'install the firebase_auth package',
    ]) {
      expect(PromptIntent.asksForChange(prompt), isTrue, reason: prompt);
    }
  });

  test('anything else asks for an answer', () {
    for (final prompt in [
      '2+2=',
      'What does this file do?',
      'How do I add a button?',
      'why is the build slow',
      'explain the fix',
      'fixes are slow',
      '',
    ]) {
      expect(PromptIntent.asksForChange(prompt), isFalse, reason: prompt);
    }
  });

  test('a prompt pointing at the open file refers to it', () {
    expect(PromptIntent.refersToOpenFile('What does this file do?'), isTrue);
    expect(PromptIntent.refersToOpenFile('Is the bug here?'), isTrue);
    expect(PromptIntent.refersToOpenFile('What does this widget do?'), isTrue);
    expect(PromptIntent.refersToOpenFile('2+2='), isFalse);
  });

  test('a prompt pointing at the whole project leaves the open file out', () {
    for (final prompt in [
      'find a typo in this project',
      'Is there dead code in the current app?',
      'review this entire codebase',
      'what does this whole repo do?',
    ]) {
      expect(PromptIntent.refersToOpenFile(prompt), isFalse, reason: prompt);
    }
  });
}
