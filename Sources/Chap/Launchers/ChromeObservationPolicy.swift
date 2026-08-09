import ApplicationServices
import Cocoa

struct ChromeProcessCandidate: Equatable {
    let pid: pid_t
    let launchDate: Date
    let isTerminated: Bool

    init(pid: pid_t, launchDate: Date, isTerminated: Bool = false) {
        self.pid = pid
        self.launchDate = launchDate
        self.isTerminated = isTerminated
    }
}

enum ChromeObservationPolicy {
    /// Relaunch overlap 중에는 동일 bundle id 프로세스가 잠시 여러 개일 수 있으므로
    /// 종료되지 않은 프로세스 중 가장 최근에 시작된 것을 현재 Chrome으로 선택한다.
    static func currentProcess(from candidates: [ChromeProcessCandidate])
        -> ChromeProcessCandidate?
    {
        candidates
            .filter { !$0.isTerminated }
            .max {
                if $0.launchDate == $1.launchDate { return $0.pid < $1.pid }
                return $0.launchDate < $1.launchDate
            }
    }

    /// pid가 바뀌면 AXUIElement identity도 모두 바뀐다. 기존 창 fingerprint를 multiset으로
    /// 차감하여 복원된 창은 baseline으로 처리하고, 남은 창만 launch 요청 후보로 반환한다.
    static func candidateIndicesAfterRelaunch(
        chromeWasRunning: Bool,
        baselineFingerprints: [String],
        currentFingerprints: [String]
    ) -> [Int] {
        guard chromeWasRunning else { return Array(currentFingerprints.indices) }
        var remaining = Dictionary(
            baselineFingerprints.map { ($0, 1) },
            uniquingKeysWith: +)
        var candidates: [Int] = []
        for (index, fingerprint) in currentFingerprints.enumerated() {
            if let count = remaining[fingerprint], count > 0 {
                remaining[fingerprint] = count - 1
            } else {
                candidates.append(index)
            }
        }
        return candidates
    }
}

/// ChromeLauncher의 OS 의존성을 한곳에 모아 관찰 정책과 분리한다.
struct ChromeRuntime {
    let processes: (_ bundleID: String) -> [ChromeProcessCandidate]
    let windows: (_ pid: pid_t) -> [AXUIElement]
    let sleep: (_ microseconds: useconds_t) -> Void

    static let live = ChromeRuntime(
        processes: { bundleID in
            NSWorkspace.shared.runningApplications.compactMap { app in
                guard app.bundleIdentifier == bundleID else { return nil }
                return ChromeProcessCandidate(
                    pid: app.processIdentifier,
                    launchDate: app.launchDate ?? .distantPast,
                    isTerminated: app.isTerminated)
            }
        },
        windows: { LauncherUtils.axWindows(pid: $0) },
        sleep: { usleep($0) })
}
