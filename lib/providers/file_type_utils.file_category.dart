part of 'file_type_utils.dart';

/// The kind of file, which picks its icon in the file trees.
enum FileCategory {
  dart(Icons.code),
  source(Icons.developer_mode),
  javascript(Icons.javascript),
  markup(Icons.code),
  stylesheet(Icons.css),
  data(Icons.data_object),
  document(Icons.text_snippet),
  config(Icons.build),
  lock(Icons.lock),
  script(Icons.terminal),
  text(Icons.article),
  image(Icons.image),
  pdf(Icons.picture_as_pdf),
  archive(Icons.archive),
  other(Icons.insert_drive_file);

  /// Icon shown for the category; [dart] uses the bundled Dart logo instead.
  final IconData icon;

  const FileCategory(this.icon);
}
