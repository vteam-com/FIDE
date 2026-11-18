import 'package:fide/providers/follow_busy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late int builds;
  late StateProvider<int> work;
  late Provider<bool> busy;
  late ProviderContainer container;

  setUp(() {
    builds = 0;
    // Pending items of some panel's work, counting its creations
    work = StateProvider<int>((_) {
      builds++;
      return 0;
    });
    busy = followBusy(work, (pending) => pending > 0);
    container = ProviderContainer();
  });

  tearDown(() => container.dispose());

  /// Lets the container tell the flag that [work] now exists.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('is false without creating the work it follows', () async {
    final seen = <bool>[];
    container.listen(busy, (_, next) => seen.add(next));

    await settle();

    expect(container.read(busy), isFalse);
    expect(builds, 0);
    expect(seen, isEmpty);
  });

  test('follows the work once something else creates it', () async {
    container.listen(busy, (_, _) {});

    container.read(work.notifier).state = 1;
    await settle();
    expect(container.read(busy), isTrue);

    container.read(work.notifier).state = 0;
    expect(container.read(busy), isFalse);
    expect(builds, 1);
  });

  test('reads work that existed before it', () {
    container.read(work.notifier).state = 1;

    expect(container.read(busy), isTrue);
  });
}
