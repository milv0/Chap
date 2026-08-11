import Foundation
import Testing

@testable import Chap

@Suite("SaveDebouncer")
struct SaveDebouncerTests {
    @Test("multiple schedules execute only the latest action")
    func debounces() {
        let queue = DispatchQueue(label: "SaveDebouncerTests.debounce")
        let debouncer = SaveDebouncer(delay: 0.05, queue: queue)
        let done = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var values: [Int] = []

        debouncer.schedule {
            lock.lock()
            values.append(1)
            lock.unlock()
        }
        debouncer.schedule {
            lock.lock()
            values.append(2)
            lock.unlock()
            done.signal()
        }

        #expect(done.wait(timeout: .now() + 1) == .success)
        lock.lock()
        let snapshot = values
        lock.unlock()
        #expect(snapshot == [2])
        #expect(!debouncer.hasPending)
    }

    @Test("flush executes a pending action immediately")
    func flushes() {
        let debouncer = SaveDebouncer(delay: 10, queue: .main)
        var count = 0
        debouncer.schedule { count += 1 }

        debouncer.flush()

        #expect(count == 1)
        #expect(!debouncer.hasPending)
    }

    @Test("cancel discards a pending action")
    func cancels() {
        let debouncer = SaveDebouncer(delay: 10, queue: .main)
        var count = 0
        debouncer.schedule { count += 1 }

        debouncer.cancel()
        debouncer.flush()

        #expect(count == 0)
        #expect(!debouncer.hasPending)
    }
}
