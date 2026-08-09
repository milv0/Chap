import ApplicationServices
import Cocoa

// 관찰(observation) 정책/결과/레지스트리/컨텍스트를 정의하는 AppLauncher 지원 타입.
// 동작 변경 없이 AppLauncher.swift에서 분리된 데이터 타입들이다.
extension AppLauncher {
    struct ResizeObservationPolicy {
        let isMicrosoftOffice: Bool
        let timeout: TimeInterval
        let postResizeGrace: TimeInterval
        let focusedFallbackDelay: TimeInterval
    }

    struct ResizeObservationResult {
        let latency: TimeInterval?
        let wasSuperseded: Bool
        let boundsResult: AXBoundsResult?
        /// 리사이즈 대상 창을 아예 못 찾았을 때의 창 상태 요약. 찾은 경우 nil.
        let diagnostic: String?

        static let superseded = ResizeObservationResult(
            latency: nil, wasSuperseded: true, boundsResult: nil, diagnostic: nil)
    }

    /// 같은 앱을 연속 실행하면 이전 AXObserver가 Office grace 시간 동안 남아 중복 스캔한다.
    /// 앱별 generation token으로 최신 관찰만 유지하고, 이전 관찰은 다음 루프에서 종료시킨다.
    final class ResizeObservationRegistry {
        private let lock = NSLock()
        private var tokensByKey: [String: Int] = [:]

        func begin(key: String) -> Int {
            lock.lock()
            defer { lock.unlock() }
            let nextToken = (tokensByKey[key] ?? 0) + 1
            tokensByKey[key] = nextToken
            return nextToken
        }

        func isCurrent(key: String, token: Int) -> Bool {
            lock.lock()
            defer { lock.unlock() }
            return tokensByKey[key] == token
        }

        func finish(key: String, token: Int) {
            lock.lock()
            defer { lock.unlock() }
            if tokensByKey[key] == token {
                tokensByKey.removeValue(forKey: key)
            }
        }
    }

    /// 윈도우 리사이즈 대상/상태를 AXObserver 콜백과 관찰 루프가 공유하는 컨텍스트.
    /// 콜백과 루프가 모두 같은 (run loop) 스레드에서 실행되므로 별도 동기화는 불필요.
    final class ResizeContext {
        let position: CGPoint
        let size: CGSize
        let startTime: CFAbsoluteTime
        let debugLabel: String
        let policy: ResizeObservationPolicy
        let observationKey: String
        let observationToken: Int
        let windowsBefore: [AXUIElement]
        /// 리사이즈에 성공한 새 창 (최대 1개; Office는 문서창을 대기해 교체 가능)
        var resizedWindow: AXUIElement?
        var resizedBoundsResult: AXBoundsResult?
        var processedWindows: [AXUIElement] = []
        var skipped: [AXUIElement] = []
        var firstResizeLatency: TimeInterval?
        var lastResizeTime: CFAbsoluteTime?
        var lastSnapshotTime: CFAbsoluteTime = 0
        var didAttemptEarlyFocusedFallback = false
        var didResize: Bool { resizedWindow != nil }
        init(
            position: CGPoint,
            size: CGSize,
            startTime: CFAbsoluteTime,
            debugLabel: String,
            policy: ResizeObservationPolicy,
            observationKey: String,
            observationToken: Int,
            windowsBefore: [AXUIElement]
        ) {
            self.position = position
            self.size = size
            self.startTime = startTime
            self.debugLabel = debugLabel
            self.policy = policy
            self.observationKey = observationKey
            self.observationToken = observationToken
            self.windowsBefore = windowsBefore
        }

        /// 이 윈도우가 baseline에 없는 새 창인지 판별
        func isNewWindow(_ window: AXUIElement) -> Bool {
            !windowsBefore.contains { CFEqual($0, window) }
        }

        func hasProcessed(_ window: AXUIElement) -> Bool {
            processedWindows.contains { CFEqual($0, window) }
        }
    }
}
