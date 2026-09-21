import Cocoa

/// CPU 사용률에 따라 상태바 번개 아이콘을 움직이는 컨트롤러.
///
/// 개념과 속도 매핑(RunnerService의 cpu/5 → 1~20fps)은 RunCat을 참고했다:
/// https://github.com/runcat-dev/RunCatNeo (Apache-2.0)
///
/// - 애니메이션이 켜져 있는 동안에만 CPU를 샘플링한다 (3초 간격, HOST_CPU_LOAD_INFO).
/// - 프레임 타이머는 CPU 사용률에 비례한 fps(1~20)로 아이콘 이미지를 순환시킨다.
/// - 모든 호출은 메인 스레드 전제다 (AppDelegate의 상태바 관리와 동일 컨텍스트).
final class StatusIconAnimator {
    private let applyImage: (NSImage) -> Void
    private var frames: [NSImage] = []
    private var frameIndex = 0
    private var frameTimer: Timer?
    private var sampleTimer: Timer?
    private var previousTicks: CPUTicks?
    private var currentFrameInterval: TimeInterval = 0

    init(applyImage: @escaping (NSImage) -> Void) {
        self.applyImage = applyImage
    }

    var isAnimating: Bool { frameTimer != nil }

    /// 스타일을 적용한다. off면 타이머·샘플링을 모두 정지한다.
    /// on이면 첫 프레임을 즉시 적용해 정적 아이콘과 자연스럽게 교대한다.
    func configure(style: StatusBarAnimationChoice) {
        stop()
        guard style != .off else { return }
        frames = Self.renderFrames(style: style)
        guard !frames.isEmpty else { return }

        frameIndex = 0
        applyImage(frames[0])
        previousTicks = Self.currentTicks()
        restartFrameTimer(
            interval: StatusIconAnimationPolicy.frameInterval(cpuPercent: 0))
        sampleTimer = Timer.scheduledTimer(
            withTimeInterval: StatusIconAnimationPolicy.sampleInterval, repeats: true
        ) { [weak self] _ in
            self?.sampleCPU()
        }
    }

    func stop() {
        frameTimer?.invalidate()
        frameTimer = nil
        sampleTimer?.invalidate()
        sampleTimer = nil
        frames = []
        previousTicks = nil
        currentFrameInterval = 0
    }

    // MARK: - CPU sampling

    private func sampleCPU() {
        guard let current = Self.currentTicks() else { return }
        defer { previousTicks = current }
        guard let previous = previousTicks else { return }

        let percent = CPUTicks.usagePercent(previous: previous, current: current)
        let interval = StatusIconAnimationPolicy.frameInterval(cpuPercent: percent)
        if abs(interval - currentFrameInterval) > 0.001 {
            restartFrameTimer(interval: interval)
        }
    }

    private func restartFrameTimer(interval: TimeInterval) {
        currentFrameInterval = interval
        frameTimer?.invalidate()
        frameTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) {
            [weak self] _ in
            self?.advanceFrame()
        }
    }

    private func advanceFrame() {
        guard !frames.isEmpty else { return }
        frameIndex = StatusIconAnimationPolicy.nextFrameIndex(
            after: frameIndex, frameCount: frames.count)
        applyImage(frames[frameIndex])
    }

    /// 전체 코어 합산 CPU 누적 틱 스냅샷.
    private static func currentTicks() -> CPUTicks? {
        var info = host_cpu_load_info_data_t()
        var size = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return CPUTicks(
            user: info.cpu_ticks.0,
            system: info.cpu_ticks.1,
            idle: info.cpu_ticks.2,
            nice: info.cpu_ticks.3)
    }

    // MARK: - Frame rendering

    /// 스타일별 키프레임을 사전 렌더링한다. 모두 22×22 template 이미지다.
    static func renderFrames(style: StatusBarAnimationChoice) -> [NSImage] {
        guard style != .off,
            let base = AppDelegate.statusBarSymbolImage(
                name: "bolt.fill", accessibilityDescription: "Chap")
        else { return [] }

        switch style {
        case .off:
            return []
        case .pulse:
            return StatusIconAnimationPolicy.pulseAlphas.map { alpha in
                renderedFrame(base: base) { rect in
                    base.draw(in: rect, from: .zero, operation: .sourceOver, fraction: alpha)
                }
            }
        case .wobble:
            return StatusIconAnimationPolicy.wobbleDegrees.map { degrees in
                renderedFrame(base: base) { rect in
                    guard let context = NSGraphicsContext.current?.cgContext else { return }
                    context.translateBy(x: rect.midX, y: rect.midY)
                    context.rotate(by: degrees * .pi / 180)
                    context.translateBy(x: -rect.midX, y: -rect.midY)
                    base.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
                }
            }
        }
    }

    private static func renderedFrame(
        base: NSImage, draw: @escaping (NSRect) -> Void
    ) -> NSImage {
        let image = NSImage(size: base.size, flipped: false) { rect in
            draw(rect)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = base.accessibilityDescription
        return image
    }
}
