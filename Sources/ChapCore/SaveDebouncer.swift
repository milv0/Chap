import Foundation

/// 빠르게 반복되는 자동 저장 요청을 하나로 합치고 필요 시 즉시 flush한다.
public final class SaveDebouncer: @unchecked Sendable {
    private struct Pending {
        let id: UUID
        let item: DispatchWorkItem
        let action: () -> Void
    }

    private let delay: TimeInterval
    private let queue: DispatchQueue
    private let lock = NSLock()
    private var pending: Pending?

    public init(delay: TimeInterval = 0.4, queue: DispatchQueue = .main) {
        self.delay = delay
        self.queue = queue
    }

    deinit {
        cancel()
    }

    func schedule(_ action: @escaping () -> Void) {
        let id = UUID()
        let item = DispatchWorkItem { [weak self] in
            self?.fire(id: id)
        }

        lock.lock()
        pending?.item.cancel()
        pending = Pending(id: id, item: item, action: action)
        lock.unlock()
        queue.asyncAfter(deadline: .now() + delay, execute: item)
    }

    func flush() {
        let action: (() -> Void)?
        lock.lock()
        pending?.item.cancel()
        action = pending?.action
        pending = nil
        lock.unlock()
        action?()
    }

    func cancel() {
        lock.lock()
        pending?.item.cancel()
        pending = nil
        lock.unlock()
    }

    var hasPending: Bool {
        lock.lock()
        defer { lock.unlock() }
        return pending != nil
    }

    private func fire(id: UUID) {
        let action: (() -> Void)?
        lock.lock()
        if pending?.id == id {
            action = pending?.action
            pending = nil
        } else {
            action = nil
        }
        lock.unlock()
        action?()
    }
}
