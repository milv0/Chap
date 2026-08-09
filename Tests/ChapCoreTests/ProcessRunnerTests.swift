import Foundation
import Testing

@testable import Chap

@Suite("ProcessRunner")
struct ProcessRunnerTests {
    @Test("captures stdout and stderr separately")
    func capturesOutputSeparately() throws {
        let result = try ProcessRunner.run(
            executable: "/bin/sh",
            arguments: ["-c", "printf out; printf err >&2"],
            timeout: 2)

        #expect(result.exitStatus == 0)
        #expect(result.stdoutString == "out")
        #expect(result.stderrString == "err")
        #expect(!result.timedOut)
    }

    @Test("captures nonzero exit status")
    func capturesExitStatus() throws {
        let result = try ProcessRunner.run(
            executable: "/bin/sh", arguments: ["-c", "exit 42"], timeout: 2)

        #expect(result.exitStatus == 42)
        #expect(!result.timedOut)
    }

    @Test("times out a long-running process")
    func timesOutLongRunningProcess() throws {
        let startedAt = Date()
        let result = try ProcessRunner.run(
            executable: "/bin/sleep", arguments: ["10"], timeout: 0.15)

        #expect(result.timedOut)
        #expect(Date().timeIntervalSince(startedAt) < 2)
    }

    @Test("caps output while continuing to drain the pipe")
    func capsLargeOutput() throws {
        let result = try ProcessRunner.run(
            executable: "/bin/sh",
            arguments: [
                "-c", "i=0; while [ $i -lt 5000 ]; do printf 1234567890; i=$((i+1)); done",
            ],
            timeout: 2,
            outputLimit: 1024)

        #expect(result.exitStatus == 0)
        #expect(result.stdout.count == 1024)
        #expect(result.stdoutTruncated)
    }

    @Test("throws when executable cannot be launched")
    func launchFailureThrows() {
        #expect(throws: ProcessRunner.RunError.self) {
            _ = try ProcessRunner.run(
                executable: "/path/that/does/not/exist", arguments: [], timeout: 1)
        }
    }
}
