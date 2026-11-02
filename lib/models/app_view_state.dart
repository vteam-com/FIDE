/// What the window shows below the title bar.
enum AppViewState {
  /// The welcome screen: open, create or reopen a project.
  welcome,

  /// The new-project wizard.
  createProject,

  /// The steps of loading a project.
  loadingProject,

  /// The IDE over the open project.
  mainLayout,
}
