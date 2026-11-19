import 'package:path/path.dart' as p;

/// The lowercase extension of [filePath]'s file name, without its dot:
/// the text after the name's last dot, empty when the name has none
/// (`Makefile`, or `/a.b/Makefile`, whose folder's dot doesn't count).
/// A dotfile with no other dot is typed by its name, so `.gitignore`
/// gives `gitignore`.
String fileExtensionOf(String filePath) {
  final name = p.basename(filePath);
  final extension = name.lastIndexOf('.') == 0 ? name : p.extension(name);
  return extension.isEmpty ? '' : extension.substring(1).toLowerCase();
}
