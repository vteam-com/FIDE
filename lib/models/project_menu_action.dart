/// What the title bar's project menu can do.
enum ProjectMenuAction {
  /// Switch to a recently opened project.
  switchProject,

  /// Fuzzy-find a project file by name and open it.
  quickOpen,

  /// Pick any file with the platform's file dialog and open it.
  openFile,

  /// Pick an existing project folder to open.
  openFolder,

  /// Start the new-project wizard.
  createProject,

  /// Close the current project.
  closeProject,
}
