part of 'app_providers.dart';

class _ProviderProjectStateSink implements ProjectStateSink {
  final Ref _ref;

  _ProviderProjectStateSink(this._ref);

  @override
  void bumpProjectTreeRevision() {
    _ref.read(projectTreeRevisionProvider.notifier).state++;
  }

  @override
  void clearSelectedFile() {
    _ref.read(selectedFileProvider.notifier).state = null;
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
  void setProjectLoaded(bool isLoaded) {
    _ref.read(projectLoadedProvider.notifier).state = isLoaded;
  }
}
