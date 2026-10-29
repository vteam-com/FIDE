/// The order entries are listed in every project tree: directories first,
/// then by name ignoring case.
class TreeOrder {
  /// Compares an entry ([aIsDirectory], [aName]) with ([bIsDirectory],
  /// [bName]); negative when the first is listed first.
  static int compare(
    bool aIsDirectory,
    String aName,
    bool bIsDirectory,
    String bName,
  ) {
    if (aIsDirectory != bIsDirectory) return aIsDirectory ? -1 : 1;
    return aName.toLowerCase().compareTo(bName.toLowerCase());
  }
}
