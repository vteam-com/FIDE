part of 'constants.dart';

/// Zero-based tab indices for the left-panel tab controller.
class AppPanelIndex {
  static const int explorer = 0;
  static const int organized = 1;
  static const int git = organized + 1;
  static const int search = git + 1;
  static const int run = search + 1;
  static const int test = run + 1;

  const AppPanelIndex._();
}
