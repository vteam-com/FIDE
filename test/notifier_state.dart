import 'package:flutter_riverpod/legacy.dart';

/// The current state of [notifier], read the way its listeners get it, for
/// tests that build a notifier directly rather than through a provider.
T stateOf<T>(StateNotifier<T> notifier) {
  late T state;
  notifier.addListener((value) => state = value)();
  return state;
}
