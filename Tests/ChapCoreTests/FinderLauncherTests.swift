import Testing

@testable import Chap

@Suite("FinderLauncher")
struct FinderLauncherTests {
    @Test("escapes quotes and backslashes in AppleScript path")
    func escapesPath() {
        let script = FinderLauncher.finderScript(
            path: #"/tmp/A "quoted" \ folder"#,
            bounds: (10, 20, 810, 620))

        #expect(script.contains(#"POSIX file "/tmp/A \"quoted\" \\ folder""#))
        #expect(script.contains("set bounds of front window to {10, 20, 810, 620}"))
    }
}
