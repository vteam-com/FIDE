import Cocoa
import Darwin
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override init() {
    AppDelegate.raiseOpenFilesLimit()
    super.init()
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  /// Raises the soft limit of open files from launchd's 256 to the most
  /// a process may open, as Terminal and VS Code do, for FIDE and every
  /// process it starts (its Terminal, Run, Test and Build): with 256,
  /// `flutter test --coverage` on a large project fails with "Too many open
  /// files" and never exits.
  static func raiseOpenFilesLimit() {
    var limit = rlimit()
    guard getrlimit(RLIMIT_NOFILE, &limit) == 0 else { return }
    // macOS refuses RLIM_INFINITY: the most a process may open is
    // kern.maxfilesperproc
    var perProcess: Int32 = 0
    var size = MemoryLayout<Int32>.size
    let wanted: rlim_t =
      sysctlbyname("kern.maxfilesperproc", &perProcess, &size, nil, 0) == 0
      ? rlim_t(perProcess) : rlim_t(OPEN_MAX)
    let target = min(wanted, limit.rlim_max)
    guard target > limit.rlim_cur else { return }
    limit.rlim_cur = target
    setrlimit(RLIMIT_NOFILE, &limit)
  }
}
