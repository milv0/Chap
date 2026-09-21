import CoreGraphics
import Foundation

/// CPU 사용률을 상태바 번개 애니메이션 속도·프레임으로 바꾸는 순수 정책.
///
/// 속도 매핑은 RunCat의 공식을 따른다:
/// https://github.com/runcat-dev/RunCatNeo (Apache-2.0, RunnerService.updateRunnerSpeed)
/// fps = clamp(cpuPercent / 5, 1...20) — 유휴에서는 초당 1프레임으로 느긋하게,
/// 최대 부하에서는 초당 20프레임으로 빠르게 움직인다.
enum StatusIconAnimationPolicy {
    static let minFramesPerSecond: Double = 1
    static let maxFramesPerSecond: Double = 20

    /// CPU 샘플링 주기 (초). 애니메이션이 켜져 있는 동안에만 샘플링한다.
    static let sampleInterval: TimeInterval = 3

    /// 펄스 스타일의 프레임별 알파. 밝음 → 어두움 → 밝음으로 고동친다.
    static let pulseAlphas: [CGFloat] = [1.0, 0.65, 0.35, 0.65]

    /// 흔들림 스타일의 프레임별 기울기 (도). 중앙 → 왼쪽 → 중앙 → 오른쪽.
    static let wobbleDegrees: [CGFloat] = [0, -14, 0, 14]

    static func framesPerSecond(cpuPercent: Double) -> Double {
        max(minFramesPerSecond, min(maxFramesPerSecond, cpuPercent / 5))
    }

    /// 프레임 타이머 간격 (초).
    static func frameInterval(cpuPercent: Double) -> TimeInterval {
        1 / framesPerSecond(cpuPercent: cpuPercent)
    }

    /// 프레임 순환. frameCount가 0 이하이면 0을 반환한다.
    static func nextFrameIndex(after index: Int, frameCount: Int) -> Int {
        guard frameCount > 0 else { return 0 }
        return (index + 1) % frameCount
    }
}

/// `host_statistics(HOST_CPU_LOAD_INFO)`의 누적 틱 스냅샷.
/// 카운터는 UInt32로 랩될 수 있어 델타 계산은 wrapping 뺄셈을 쓴다.
struct CPUTicks: Equatable {
    let user: UInt32
    let system: UInt32
    let idle: UInt32
    let nice: UInt32

    /// 두 스냅샷 사이의 CPU 사용률 (0~100).
    static func usagePercent(previous: CPUTicks, current: CPUTicks) -> Double {
        let user = current.user &- previous.user
        let system = current.system &- previous.system
        let nice = current.nice &- previous.nice
        let idle = current.idle &- previous.idle
        let busy = Double(user) + Double(system) + Double(nice)
        let total = busy + Double(idle)
        guard total > 0 else { return 0 }
        return busy / total * 100
    }
}
