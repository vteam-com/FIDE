/// The pages of the new-project wizard, in order.
enum CreateProjectStep {
  /// Name, parent folder, tools and AI generation.
  nameAndFolder,

  /// Languages and the default one.
  localization,

  /// Creation running, then done.
  creating,
}
