import Foundation
import Testing

@testable import Chap

@Suite("Shelf scan coordinator", .serialized)
struct ShelfScanCoordinatorTests {
    @Test("overlapping requests share one scan and all receive its snapshot")
    @MainActor
    func overlappingRequestsCoalesce() async {
        let queue = DispatchQueue(label: "ChapShelfScanCoordinatorTests")
        let coordinator = ShelfScanCoordinator<Int>(queue: queue)
        let gate = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var scanCount = 0

        let values = await withCheckedContinuation { continuation in
            var received: [Int] = []
            let receive: (Int) -> Void = { value in
                received.append(value)
                if received.count == 2 { continuation.resume(returning: received) }
            }
            coordinator.request(
                scan: {
                    lock.withLock { scanCount += 1 }
                    gate.wait()
                    return 42
                },
                completion: receive)
            // 첫 scan이 gate에서 기다리는 동안 두 번째 요청을 동기적으로 등록한다.
            coordinator.request(
                scan: {
                    Issue.record("overlapping request started a second scan")
                    return -1
                },
                completion: receive)
            gate.signal()
        }

        #expect(values == [42, 42])
        #expect(lock.withLock { scanCount } == 1)
    }

    @Test("a request after delivery starts a fresh scan")
    @MainActor
    func laterRequestStartsNewScan() async {
        let queue = DispatchQueue(label: "ChapShelfScanCoordinatorTests.later")
        let coordinator = ShelfScanCoordinator<Int>(queue: queue)
        let lock = NSLock()
        var scanCount = 0

        func request() async -> Int {
            await withCheckedContinuation { continuation in
                coordinator.request(
                    scan: {
                        lock.withLock {
                            scanCount += 1
                            return scanCount
                        }
                    },
                    completion: { continuation.resume(returning: $0) })
            }
        }

        #expect(await request() == 1)
        #expect(await request() == 2)
    }
}
