import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

/// A flag following whether [source]'s work runs, as [isBusy] reads it
/// from [source]'s state, without creating [source]: false until something
/// else, such as its panel, creates it. A side panel tab rings its icon
/// with it, so the ring never starts the work it shows, such as a
/// project-wide analysis.
///
/// [source] must not be autoDispose: once it exists, the flag keeps it.
Provider<bool> followBusy<T>(
  ProviderBase<T> source,
  bool Function(T state) isBusy,
) => Provider<bool>(
  (ref) => ref.watch(source.exists) && ref.watch(source.select(isBusy)),
);
