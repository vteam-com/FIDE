import 'package:fide/services/image_differ.dart';
import 'package:fide/services/image_inspector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides the [ImageInspector] the image details and ICO previews read
/// image files with; override in tests to fake the decoding.
final imageInspectorProvider = Provider<ImageInspector>(
  (_) => const ImageInspector(),
);

/// Provides the [ImageDiffer] the image diff compares versions with.
final imageDifferProvider = Provider<ImageDiffer>((_) => const ImageDiffer());
