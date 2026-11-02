import Foundation

/// 같은 시점에 겹친 파일 선반 스캔 요청을 한 번으로 합치고 결과를 모든 호출자에게 돌려준다.
/// 실제 파일 I/O는 전달받은 utility queue에서, 캐시와 SwiftUI completion은 main queue에서 실행한다.
final class ShelfScanCoordinator<Snapshot>: @unchecked Sendable {
    private let queue: DispatchQueue
    private let lock = NSLock()
    private var isScanning = false
    private var completions: [(Snapshot) -> Void] = []

    init(queue: DispatchQueue) {
        self.queue = queue
    }

    func request(scan: @escaping () -> Snapshot, completion: @escaping (Snapshot) -> Void) {
        lock.lock()
        completions.append(completion)
        let shouldStart = !isScanning
        if shouldStart { isScanning = true }
        lock.unlock()

        guard shouldStart else { return }
        queue.async { [self] in
            let snapshot = scan()
            DispatchQueue.main.async { [self] in
                lock.lock()
                let waiting = completions
                completions.removeAll(keepingCapacity: true)
                isScanning = false
                lock.unlock()
                waiting.forEach { $0(snapshot) }
            }
        }
    }
}
