/// The `x.y.z` version a tool prints right after [name] in [output], as
/// `Flutter 3.24.0 • channel stable` or `git version 2.39.3` do; null when
/// the output doesn't hold one.
String? versionAfter(String name, String output) =>
    RegExp('${RegExp.escape(name)} (\\d+\\.\\d+\\.\\d+)')
        .firstMatch(output)
        ?.group(1);
