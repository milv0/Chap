import Darwin
import Foundation

/// 외부 프로세스를 timeout과 출력 제한 아래 실행한다.
/// stdout/stderr를 별도 큐에서 동시에 끝까지 drain하여 pipe buffer deadlock을 방지한다.
enum ProcessRunner {
    enum RunError: Error {
        case launchFailed(Error)
        case terminationFailed(processIdentifier: Int32)
    }

    struct Result {
        let exitStatus: Int32
        let stdout: Data
        let stderr: Data
        let stdoutTruncated: Bool
        let stderrTruncated: Bool
        let timedOut: Bool

        var stdoutString: String {
            String(data: stdout, encoding: .utf8) ?? ""
        }

        var stderrString: String {
            String(data: stderr, encoding: .utf8) ?? ""
        }
    }

    private final class OutputCollector: @unchecked Sendable {
        private let limit: Int
        private let lock = NSLock()
        private var storage = Data()
        private var didTruncate = false

        init(limit: Int) {
            self.limit = max(0, limit)
        }

        func append(_ chunk: Data) {
            lock.lock()
            defer { lock.unlock() }
            let remaining = limit - storage.count
            if remaining > 0 {
                storage.append(chunk.prefix(remaining))
            }
            if chunk.count > max(0, remaining) {
                didTruncate = true
            }
        }

        var snapshot: (data: Data, truncated: Bool) {
            lock.lock()
            defer { lock.unlock() }
            return (storage, didTruncate)
        }
    }

    static func run(
        executable: String,
        arguments: [String],
        timeout: TimeInterval,
        outputLimit: Int = 512 * 1024,
        environment: [String: String]? = nil
    ) throws -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let environment { process.environment = environment }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let terminated = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in terminated.signal() }

        do {
            try process.run()
        } catch {
            stdoutPipe.fileHandleForReading.closeFile()
            stderrPipe.fileHandleForReading.closeFile()
            stdoutPipe.fileHandleForWriting.closeFile()
            stderrPipe.fileHandleForWriting.closeFile()
            throw RunError.launchFailed(error)
        }

        // The parent must not keep the write ends alive; otherwise readers never observe EOF.
        stdoutPipe.fileHandleForWriting.closeFile()
        stderrPipe.fileHandleForWriting.closeFile()
        let stdoutCollector = OutputCollector(limit: outputLimit)
        let stderrCollector = OutputCollector(limit: outputLimit)
        let readers = DispatchGroup()
        drain(
            stdoutPipe.fileHandleForReading, into: stdoutCollector,
            group: readers, label: "com.mingyupark.Chap.ProcessRunner.stdout")
        drain(
            stderrPipe.fileHandleForReading, into: stderrCollector,
            group: readers, label: "com.mingyupark.Chap.ProcessRunner.stderr")

        let didTimeout = terminated.wait(timeout: .now() + max(0.01, timeout)) == .timedOut
        if didTimeout {
            terminate(process)
            _ = terminated.wait(timeout: .now() + 1)
        }

        // A descendant can inherit the pipe after the direct child exits. The runner never waits
        // without a bound; late readers finish when their inherited write end closes.
        _ = readers.wait(timeout: .now() + 1)

        // Foundation raises an Objective-C exception when terminationStatus is read while the
        // process is still running. Treat an unsuccessful kill as an ordinary Swift error instead.
        guard !process.isRunning else {
            throw RunError.terminationFailed(processIdentifier: process.processIdentifier)
        }

        let stdout = stdoutCollector.snapshot
        let stderr = stderrCollector.snapshot
        return Result(
            exitStatus: process.terminationStatus,
            stdout: stdout.data,
            stderr: stderr.data,
            stdoutTruncated: stdout.truncated,
            stderrTruncated: stderr.truncated,
            timedOut: didTimeout)
    }

    private static func drain(
        _ handle: FileHandle,
        into collector: OutputCollector,
        group: DispatchGroup,
        label: String
    ) {
        group.enter()
        DispatchQueue(label: label, qos: .utility).async {
            defer { group.leave() }
            while true {
                guard let chunk = try? handle.read(upToCount: 64 * 1024),
                    !chunk.isEmpty
                else { return }
                collector.append(chunk)
            }
        }
    }

    private static func terminate(_ process: Process) {
        guard process.isRunning else { return }
        process.terminate()
        let deadline = Date().addingTimeInterval(0.25)
        while process.isRunning, Date() < deadline {
            usleep(10_000)
        }
        if process.isRunning {
            kill(process.processIdentifier, SIGKILL)
        }
    }
}
