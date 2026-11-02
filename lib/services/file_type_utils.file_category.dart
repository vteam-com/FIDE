part of 'file_type_utils.dart';

/// The kind of file, which picks its icon in the file trees
/// (`FileIconUtils` maps it to the icon).
enum FileCategory {
  dart,
  source,
  javascript,
  markup,
  stylesheet,
  data,
  document,
  config,
  lock,
  script,
  text,
  image,
  pdf,
  archive,
  other,
}
