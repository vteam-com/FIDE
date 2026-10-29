/// The sections of the Organized view, in display order, with the project
/// folders whose contents belong to each.
enum CodeCategory {
  /// Screens and pages.
  views('Views', ['lib/views', 'lib/screens', 'lib/pages']),

  /// Dialogs, plus any non-view file that calls `showDialog`.
  dialogs('Dialogs', ['lib/dialogs']),

  /// Reusable widgets.
  widgets('Widgets', ['lib/widgets']),

  /// Services.
  services('Services', ['lib/services']),

  /// Providers and controllers.
  controllers('Controllers', ['lib/providers', 'lib/controls']),

  /// Data models.
  models('Models', ['lib/models', 'lib/data']),

  /// ARB translation files.
  localization('Localization', ['lib/l10n', 'l10n']);

  /// Section title.
  final String label;

  /// Project-relative folders whose entries belong to this category.
  final List<String> directories;

  const CodeCategory(this.label, this.directories);
}
