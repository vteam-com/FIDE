import 'package:fide/models/flutter_platform.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/desktop_shell.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'one overridable host operating system drives every platform choice',
    () {
      final container = ProviderContainer(
        overrides: [hostOperatingSystemProvider.overrideWithValue('windows')],
      );
      addTearDown(container.dispose);

      expect(container.read(desktopShellProvider), isA<WindowsDesktopShell>());
      expect(container.read(hostPlatformProvider), FlutterPlatform.windows);
      expect(
        container.read(ollamaInstallerProvider).operatingSystem,
        'windows',
      );
    },
  );
}
