part of 'app_providers.dart';

class _ProviderProjectStateSink implements ProjectStateSink {
  final Ref _ref;

  _ProviderProjectStateSink(this._ref);

  @override
  List<LoadingAction> get loadingActions => _ref.read(loadingActionsProvider);

  @override
  void clearSelectedFile() {
    _ref.read(selectedFileProvider.notifier).state = null;
  }

  @override
  void replaceLoadingActions(List<LoadingAction> actions) {
    _ref.read(loadingActionsProvider.notifier).state = actions;
  }

  @override
  void setCurrentProjectPath(String? path) {
    _ref.read(currentProjectPathProvider.notifier).state = path;
  }

  @override
  void setCurrentProjectRoot(ProjectNode? root) {
    _ref.read(currentProjectRootProvider.notifier).state = root;
  }

  @override
  void setProjectCreationError(String? message) {
    _ref.read(projectCreationErrorProvider.notifier).state = message;
  }

  @override
  void setProjectLoaded(bool isLoaded) {
    _ref.read(projectLoadedProvider.notifier).state = isLoaded;
  }
}
