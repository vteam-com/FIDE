import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

/// What [read] takes from [source]'s state, without creating [source]:
/// [none] until something else, such as its panel, creates it. A side
/// panel tab rings its icon and counts its badge with it, so its header
/// never starts the work it shows, such as a project-wide analysis.
///
/// [source] must not be autoDispose: once it exists, the follower keeps it.
Provider<R> follow<T, R>(
  ProviderBase<T> source,
  R Function(T state) read, {
  required R none,
}) => Provider<R>(
  (ref) => ref.watch(source.exists) ? ref.watch(source.select(read)) : none,
);

/// A flag following whether [source]'s work runs, as [isBusy] reads it
/// from [source]'s state, through [follow]: false until something else
/// creates [source]. A side panel tab rings its icon with it.
Provider<bool> followBusy<T>(
  ProviderBase<T> source,
  bool Function(T state) isBusy,
) => follow(source, isBusy, none: false);
