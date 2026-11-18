import 'dart:ui';

import 'package:flutter/services.dart';

/// Quits FIDE without asking first, as its Quit menu item and its update
/// do: the one exit request the macOS, Windows and Linux embedders all
/// honor, where Windows ignores `SystemNavigator.pop`.
Future<void> quitApp() =>
    ServicesBinding.instance.exitApplication(AppExitType.required);
