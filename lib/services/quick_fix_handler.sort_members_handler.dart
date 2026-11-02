part of 'quick_fix_handler.dart';

/// Runs [QuickFix.sortMembers] with fCheck's own sorter.
class SortMembersHandler implements QuickFixHandler {
  /// Creates the handler sorting through [_review].
  const SortMembersHandler(this._review);

  final CodeReview _review;

  @override
  Future<QuickFixOutcome> run(QuickFixRequest request) async {
    if (request.metrics.sourceSortIssues.isEmpty) {
      return _nothingToDo('Members already sorted');
    }
    final changed = await _review.sortMembers(request.projectPath);
    return (
      summary: 'Sorted members in ${changed.length.localized} files',
      changedFiles: changed,
    );
  }
}
