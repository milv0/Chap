import SwiftUI

/// Chap 마스코트(아기 물범). 픽셀마다 사각형을 칠해 어떤 배율에서도 도트가 선명하다.
/// - 깨어 있음(`.awake`, `.drowsy`): 노치를 열면 꼬리를 한 번 까딱하고, 열려 있는 동안
///   7~12초마다 까딱, 4~7초마다 깜빡인다. 졸릴 때는 눈꺼풀이 무겁다.
/// - 잠(`.asleep`): 눈을 감고 머리 위로 z가 3초마다 하나씩 떠오른다.
/// `isAnimating`이 false(노치 닫힘)거나 동작 줄이기가 켜져 있으면 움직이지 않고, 상태별
/// 정지 모습(잠든 물범은 z가 떠 있는 채)만 보인다. 장식이므로 누를 수 없고 VoiceOver에서도 건너뛴다.
struct NotchMascotView: View {
    var pixelSize: CGFloat = ChapMascot.stripPixelSize
    var mood: ChapMascot.FocusMood = .awake
    var isAnimating = false
    /// true면 깨어 있는 동안 꼬리를 쉬지 않고 흔든다(Focus 칸). false면 가끔 까딱(띠).
    var wagsContinuously = false
    /// z 색. 배경 위 보조 텍스트와 같은 색을 받는다.
    var zColor: Color = .secondary
    /// Focus가 켜져 있는지. 켜지는 순간 첨벙 다이빙을 한 번 하고(몰입), 켜져 있는 동안 꼬리를 흔든다.
    var isFocusing = false
    /// 잠든 동안에도 가끔 꿈꾸듯 꼬리를 한 번 까딱한다 (Cover Screens 화면). 노치 띠에서는 쓰지 않는다.
    var dreams = false
    /// 깨어 있을 때 꼬리를 까딱하는 간격(초). 노치 띠는 기본값, Cover Screens 보조 화면은 더 짧게.
    var flickInterval: ClosedRange<Double> = ChapMascot.idleFlickInterval

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pose: ChapMascot.Pose = .rest
    /// 다이빙 중인 프레임. nil이면 평소 모습.
    @State private var diveStep: ChapMascot.FocusDiveStep?
    /// 처음 나타날 때는 이미 켜져 있던 Focus라 뛰어들지 않는다(켜는 순간에만 한다).
    @State private var didAppear = false
    @State private var isBlinking = false
    @State private var zRisen = false

    private var moves: Bool { isAnimating && !reduceMotion }

    private var eyes: ChapMascot.Eyes {
        isBlinking && mood != .asleep ? .closed : mood.eyes
    }

    /// 지금 물범 세로 위치(픽셀). 다이빙 중에만 오르내린다.
    private var offsetY: Int { diveStep?.offsetY ?? 0 }

    /// 지금 수면. 다이빙 중에만 있고, 물범은 이 행보다 아래 부분이 그려지지 않는다.
    private var surface: (level: Int, phase: Int)? {
        guard let diveStep, let level = diveStep.waterLevel else { return nil }
        return (level, diveStep.wavePhase)
    }

    /// 지금 그릴 물과 물방울 (다이빙 중에만).
    private var water: [ChapMascot.Pixel] {
        guard let diveStep else { return [] }
        guard let level = diveStep.waterLevel else { return diveStep.splash }
        return ChapMascot.waterPixels(
            level: level, phase: diveStep.wavePhase, rows: diveStep.waterRows)
            + diveStep.splash
    }

    private func play(_ steps: [ChapMascot.FocusDiveStep]) async {
        for step in steps {
            diveStep = step
            pose = step.pose
            try? await Task.sleep(for: .seconds(ChapMascot.focusDiveFrameDuration))
            if Task.isCancelled { break }
        }
        diveStep = nil
        pose = .rest
    }

    /// 까딱 한 번을 재생한다. 취소되면 쉬는 자세로 돌아간다.
    private func flick() async {
        guard diveStep == nil else { return }
        for next in ChapMascot.flickSequence {
            pose = next
            try? await Task.sleep(for: .seconds(ChapMascot.flickFrameDuration))
            if Task.isCancelled { break }
        }
        pose = .rest
    }

    /// 잉크 색은 `ChapMascot.rgb`가 단일 출처다.
    private static func color(_ ink: ChapMascot.Ink) -> Color { Color(ChapMascot.rgb(ink)) }

    var body: some View {
        Canvas { context, _ in
            for pixel in ChapMascot.pixels(eyes: eyes, pose: pose) {
                // 수면 아래로 내려간 부분은 그리지 않는다(물속으로 들어간 모습).
                if let surface,
                    pixel.y + offsetY
                        >= ChapMascot.surfaceRow(
                            x: pixel.x, level: surface.level, phase: surface.phase)
                {
                    continue
                }
                let rect = CGRect(
                    x: CGFloat(pixel.x) * pixelSize, y: CGFloat(pixel.y) * pixelSize,
                    width: pixelSize, height: pixelSize)
                context.fill(Path(rect), with: .color(Self.color(pixel.ink)))
            }
        }
        .frame(
            width: CGFloat(ChapMascot.width) * pixelSize,
            height: CGFloat(ChapMascot.height) * pixelSize
        )
        .offset(y: CGFloat(offsetY) * pixelSize)
        // 물과 물방울: 물범이 뛰고 가라앉아도 수면은 제자리다(겹침은 offset 전 레이아웃 기준이라 따라 움직이지 않는다).
        // 몸보다 넓고 위로 튀는 물방울도 있어 레이아웃 크기에 넣지 않는 겹침 레이어로 그린다.
        .overlay(alignment: .topLeading) {
            let pad = 4
            Canvas { context, _ in
                for pixel in water {
                    let rect = CGRect(
                        x: CGFloat(pixel.x + pad) * pixelSize,
                        y: CGFloat(pixel.y + pad) * pixelSize,
                        width: pixelSize, height: pixelSize)
                    context.fill(Path(rect), with: .color(Self.color(pixel.ink)))
                }
            }
            .frame(
                width: CGFloat(ChapMascot.width + 2 * pad) * pixelSize,
                height: CGFloat(ChapMascot.waterBottom + 1 + pad) * pixelSize
            )
            .offset(x: -CGFloat(pad) * pixelSize, y: -CGFloat(pad) * pixelSize)
            .allowsHitTesting(false)
        }
        // Focus가 켜지는 순간(꺼짐 → 켜짐) 첨벙 다이빙을 한 번 한다. 이미 켜져 있던 Focus(처음 나타날 때)나
        // 동작 줄이기·닫힌 노치에서는 하지 않는다.
        .task(id: isFocusing) {
            guard didAppear else {
                didAppear = true
                return
            }
            guard moves, isFocusing else { return }
            await play(ChapMascot.focusDiveSequence)
        }
        // z는 레이아웃 크기에 넣지 않고 머리 오른쪽 위에 겹쳐 그린다.
        .overlay(alignment: .topLeading) {
            if mood == .asleep {
                sleepZ
                    .offset(
                        x: 11 * pixelSize,
                        y: (zRisen ? -9 : -5) * pixelSize
                    )
                    .opacity(moves ? (zRisen ? 0 : 1) : 1)
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
        // 할 일을 하나 끝내면 꼬리를 한 번 까딱해 함께 기뻐한다(동작 줄이기·닫힌 노치에서는 하지 않는다).
        .onReceive(
            NotificationCenter.default.publisher(for: NotchTodoView.didCompleteNotification)
        ) { _ in
            guard moves, diveStep == nil else { return }
            Task { await flick() }
        }
        // 꼬리: 깨어 있는 동안에만. 잠에서 깨면(mood 변경) 곧바로 한 번 까딱해 반긴다.
        // Focus 칸에서는 그 뒤 쉬지 않고 흔들며, 졸리면 느려진다.
        .task(id: "\(moves)-\(mood)-\(wagsContinuously)-\(dreams)-\(flickInterval)") {
            pose = .rest
            // 잠든 채 꿈꾸기: 드물게 한 번만 까딱한다.
            if moves, mood == .asleep, dreams {
                while !Task.isCancelled {
                    try? await Task.sleep(
                        for: .seconds(Double.random(in: ChapMascot.dreamFlickInterval)))
                    if Task.isCancelled { break }
                    for next in ChapMascot.dreamFlickSequence {
                        pose = next
                        try? await Task.sleep(for: .seconds(ChapMascot.flickFrameDuration * 2))
                    }
                }
                pose = .rest
                return
            }
            guard moves, mood != .asleep else { return }
            try? await Task.sleep(for: .seconds(ChapMascot.openFlickDelay))
            if wagsContinuously, let frame = ChapMascot.focusWagFrameDuration(for: mood) {
                await flick()
                while !Task.isCancelled {
                    if diveStep == nil { pose = pose == .rest ? .tailUp : .rest }
                    try? await Task.sleep(for: .seconds(frame))
                }
                pose = .rest
                return
            }
            while !Task.isCancelled {
                await flick()
                let wait = Double.random(in: flickInterval)
                try? await Task.sleep(for: .seconds(wait))
            }
            pose = .rest
        }
        // 깜빡임: 깨어 있는 동안 불규칙하게.
        .task(id: [moves, mood != .asleep]) {
            isBlinking = false
            guard moves, mood != .asleep else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: ChapMascot.blinkInterval)))
                if Task.isCancelled { break }
                isBlinking = true
                try? await Task.sleep(for: .seconds(ChapMascot.blinkDuration))
                isBlinking = false
            }
            isBlinking = false
        }
        // z: 잠든 동안 하나씩 떠올라 흐려진다.
        .task(id: [moves, mood == .asleep]) {
            zRisen = false
            guard moves, mood == .asleep else { return }
            while !Task.isCancelled {
                zRisen = false
                try? await Task.sleep(for: .milliseconds(50))
                withAnimation(.easeOut(duration: ChapMascot.sleepZRiseDuration)) { zRisen = true }
                try? await Task.sleep(for: .seconds(ChapMascot.sleepZPeriod))
            }
            zRisen = false
        }
    }

    private var sleepZ: some View {
        Canvas { context, _ in
            for (y, row) in ChapMascot.sleepZRows.enumerated() {
                for (x, ch) in row.enumerated() where ch == "o" {
                    let rect = CGRect(
                        x: CGFloat(x) * pixelSize, y: CGFloat(y) * pixelSize,
                        width: pixelSize, height: pixelSize)
                    context.fill(Path(rect), with: .color(zColor))
                }
            }
        }
        .frame(width: 4 * pixelSize, height: 4 * pixelSize)
    }
}
