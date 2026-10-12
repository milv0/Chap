import AppKit
import IOKit.pwr_mgt
import SwiftUI

/// Cover Screens: 자리를 비울 때 모든 화면을 검정으로 덮는 가림막.
///
/// **잠금이 아니다.** 비밀번호를 묻지 않고, Chap이 끝나면 걷힌다. 어깨너머 시선을 가리는
/// 용도이며 진짜 보안은 macOS 화면 잠금(⌃⌘Q)이 맡는다.
///
/// 걷기: ⌥(Option)만 한 번 눌렀다 떼면 된다(`CoverScreensPolicy.OptionTap`). 잊었으면 아무 키나 15번 빠르게.
/// 덮여 있는 동안 Chap이 키 포커스를 갖고, 다른 앱이 활성화되면(⌘Tab 등) 곧바로 되찾는다.
/// 그래도 키가 다른 앱으로 간 경우를 위해 전역 모니터(접근성 권한이 있을 때)로 ⌥와 연타를 계속 본다
/// — 걷는 길이 포커스에 매이지 않게 하기 위해서다(FLOW I19).
///
/// Keep Mac Awake와 독립이다. 가림막은 켜져 있는 동안 자기 몫의 IOKit 어써션을 들기 때문에,
/// Keep Awake가 꺼져 있어도 화면이 꺼지지 않고, Keep Awake 세션이 끝나도 가림막은 그대로다.
/// 상태는 메모리에만 있다(다음 실행은 늘 꺼진 상태로 시작한다). 메인 스레드 전제이며,
/// AppDelegate(메인 스레드)에서만 호출한다.
final class CoverScreensController {
    /// 켜지거나 꺼질 때 메뉴를 다시 그리도록 알린다.
    static let didChangeNotification = Notification.Name("ChapCoverScreensDidChange")

    private var windows: [NSWindow] = []
    private var assertionID = IOPMAssertionID(0)
    private var hasAssertion = false
    private var keyMonitor: Any?
    /// Chap이 키 포커스를 잃었을 때도 ⌥·연타를 보는 전역 모니터 (접근성 권한 필요, 삼키지 못함).
    private var globalKeyMonitor: Any?
    /// ⌥ 탭 판정. 켤 때 ⌥가 눌려 있었는지로 시작한다(⌥L을 떼는 순간 걷히지 않게).
    private var screenObserver: NSObjectProtocol?
    private var resignObserver: NSObjectProtocol?
    /// 켜기 직전 앞에 있던 앱. 걷은 뒤 그 앱으로 돌려준다(안 그러면 입력이 창 없는 Chap에 간다).
    private var previousApp: NSRunningApplication?
    private var optionTap = CoverScreensPolicy.OptionTap(optionHeldAtStart: false)
    /// 비상 해제 판정용 최근 키 입력 시각.
    private var recentPresses: [Date] = []

    /// 가림막에 띄울 사용자 문구. AppDelegate가 config를 넘겨준다.
    var messageProvider: () -> String? = { nil }

    private(set) var isOn = false

    func toggle() { isOn ? turnOff() : turnOn() }

    func turnOn() {
        guard !isOn else { return }
        isOn = true
        recentPresses = []
        optionTap = CoverScreensPolicy.OptionTap(
            optionHeldAtStart: NSEvent.modifierFlags.contains(.option))
        let frontmost = NSWorkspace.shared.frontmostApplication
        previousApp =
            frontmost?.processIdentifier == ProcessInfo.processInfo.processIdentifier
            ? nil : frontmost
        holdDisplayAwake()
        installWindows()
        installKeyMonitor()
        // ⌘Tab 등으로 다른 앱이 앞에 오면 포커스를 되찾는다. 가려진 앱에 입력이 들어가지 않게.
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.reclaimFocus()
        }
        // 화면 연결·해상도 변경 때 새 화면도 덮는다.
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.installWindows()
        }
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    func turnOff() {
        guard isOn else { return }
        isOn = false
        recentPresses = []
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        if let globalKeyMonitor { NSEvent.removeMonitor(globalKeyMonitor) }
        globalKeyMonitor = nil
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        screenObserver = nil
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        resignObserver = nil
        windows.forEach { $0.orderOut(nil) }
        windows = []
        releaseDisplayAwake()
        // 쓰던 앱으로 돌아간다.
        previousApp?.activate()
        previousApp = nil
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    /// 덮여 있는 화면 수 (테스트·진단용).
    var coveredScreenCount: Int { windows.count }

    private func reclaimFocus() {
        guard isOn else { return }
        // 다음 틱에: 활성화 전환이 끝나기 전에 부르면 시스템이 다시 빼앗아 간다.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isOn, self.windows.indices.contains(self.keyWindowIndex) else {
                return
            }
            NSApp.activate(ignoringOtherApps: true)
            self.windows[self.keyWindowIndex].makeKeyAndOrderFront(nil)
        }
    }

    // MARK: - 화면

    /// 화면마다 창을 하나씩. 내장 화면(없으면 첫 화면)에는 시계·낮잠 물범·문구를, 나머지 화면에는
    /// 헤엄치는 물범을 그린다. 시계 화면의 창이 key가 되어 입력을 받는다.
    private func installWindows() {
        windows.forEach { $0.orderOut(nil) }
        let screens = NSScreen.screens
        let clockIndex = CoverScreensPolicy.clockScreenIndex(builtIn: screens.map(Self.isBuiltIn))
        windows = screens.enumerated().map { index, screen in
            let window = CoverScreensWindow(
                contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.setFrame(screen.frame, display: true)
            // 노치 도커(.statusBar)와 HUD보다 위에 와야 아무것도 비치지 않는다.
            window.level = .screenSaver
            window.isOpaque = true
            window.backgroundColor = .black
            window.hasShadow = false
            window.ignoresMouseEvents = false
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
            if index == clockIndex {
                window.contentView = NSHostingView(
                    rootView: CoverScreensView(
                        showsClock: true, hint: CoverScreensPolicy.hint, message: messageProvider())
                )
            } else {
                // 화면마다 출발점을 엇갈려, 여러 대여도 같은 자리에서 같이 헤엄치지 않게 한다.
                window.contentView = NSHostingView(
                    rootView: CoverScreensSwimView(startOffset: Double(index) * 37))
            }
            window.orderFrontRegardless()
            return window
        }
        guard windows.indices.contains(clockIndex) else { return }
        keyWindowIndex = clockIndex
        NSApp.activate(ignoringOtherApps: true)
        windows[clockIndex].makeKeyAndOrderFront(nil)
    }

    /// 입력을 받는 창(시계 화면).
    private var keyWindowIndex = 0

    private static func isBuiltIn(_ screen: NSScreen) -> Bool {
        guard
            let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
                as? CGDirectDisplayID
        else { return false }
        return CGDisplayIsBuiltin(id) != 0
    }

    // MARK: - 입력

    /// 가림막이 떠 있는 동안의 입력. ⌥ 탭이나 빠른 연타면 걷고, 그 외 키는 삼킨다
    /// (가려진 앱에 눈먼 입력이 들어가지 않게). ⌥는 일반 키가 아니라 수식키 변화(flagsChanged)로 온다.
    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) {
            [weak self] event in
            guard let self, self.isOn else { return event }
            self.handle(event)
            return nil
        }
        // 다른 앱이 키를 가져간 경우의 대비. 접근성 권한이 없으면 아무것도 오지 않을 뿐 해롭지 않다.
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .flagsChanged]) {
            [weak self] event in
            guard let self, self.isOn else { return }
            self.handle(event)
            self.reclaimFocus()
        }
    }

    /// 입력 하나를 처리한다. 걷었으면 true. (테스트에서 직접 부른다.)
    @discardableResult
    func handle(_ event: NSEvent, now: Date = Date()) -> Bool {
        if event.type == .flagsChanged {
            let flags = event.modifierFlags
            let others: NSEvent.ModifierFlags = [.command, .control, .shift, .function]
            guard
                optionTap.modifiersChanged(
                    optionDown: flags.contains(.option),
                    otherModifiersDown: !flags.intersection(others).isEmpty)
            else { return false }
            turnOff()
            return true
        }
        // ⌥를 누른 채 다른 키를 치면 그 ⌥는 탭이 아니다.
        optionTap.otherKeyPressed()
        // ⌥를 잊었을 때: 아무 키나 빠르게 15번. 누르고 있는 자동 반복은 세지 않는다.
        guard CoverScreensPolicy.countsAsPress(isRepeat: event.isARepeat) else { return false }
        recentPresses = CoverScreensPolicy.recentPresses(recentPresses + [now], now: now)
        guard CoverScreensPolicy.isRapidEscape(presses: recentPresses, now: now) else {
            return false
        }
        turnOff()
        return true
    }

    // MARK: - 화면 꺼짐 방지

    private func holdDisplayAwake() {
        guard !hasAssertion else { return }
        var id = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Chap Cover Screens" as CFString,
            &id)
        guard result == kIOReturnSuccess else {
            // 어써션이 없으면 화면이 꺼질 수 있다. 가림막 자체는 그대로 둔다.
            Log.app.error("Cover Screens assertion failed: \(result, privacy: .public)")
            return
        }
        assertionID = id
        hasAssertion = true
    }

    private func releaseDisplayAwake() {
        guard hasAssertion else { return }
        IOPMAssertionRelease(assertionID)
        hasAssertion = false
        assertionID = IOPMAssertionID(0)
    }
}

/// 가림막 창. 활성화 정책이 accessory여도 key가 되어 입력을 받아야 한다.
final class CoverScreensWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    /// 클릭은 삼킨다. 가려진 앱이 눈먼 클릭을 받지 않게.
    override func mouseDown(with event: NSEvent) {}
}

/// 가림막 내용: 검정 바탕에 자는 물범, 시간, 그리고 잠깐 떴다 사라지는 안내.
/// (개발용) 렌더 도구가 모습을 PNG로 뽑을 때도 쓴다.
struct CoverScreensView: View {
    /// 주 화면에만 시간과 안내를 둔다. 나머지 화면은 검정만.
    let showsClock: Bool
    let hint: String
    /// 사용자가 설정한 문구. 시계 아래에 계속 보인다(안내와 달리 사라지지 않는다). nil이면 없음.
    var message: String?

    @State private var showsHint = true
    /// 숨: 들숨이면 true. 밝기만 오르내린다.
    @State private var inhales = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var sealOpacity: Double {
        guard !reduceMotion else { return CoverScreensPolicy.sealOpacity }
        let range = CoverScreensPolicy.sealBreathOpacity
        return inhales ? range.upperBound : range.lowerBound
    }

    var body: some View {
        ZStack {
            Color.black
            if showsClock {
                VStack(spacing: 24) {
                    // 노치와 같은 물범이 잔다: z가 하나씩 떠올라 흐려지고, 가끔 꿈꾸듯 꼬리를 까딱하며,
                    // 숨 쉬듯 밝기가 오르내린다. 물범 자리는 그대로이고 z는 머리 위 여백에서만 움직인다.
                    NotchMascotView(
                        pixelSize: 6, mood: .asleep, isAnimating: true, zColor: .white, dreams: true
                    )
                    // z가 머리 위(최대 9칸)로 떠오를 자리. 레이아웃에 넣어 시계와 겹치지 않게 한다.
                    .padding(.top, 9 * 6)
                    .opacity(sealOpacity)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(context.date, format: .dateTime.hour().minute())
                            .font(.system(size: 64, weight: .thin, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(.white.opacity(CoverScreensPolicy.clockOpacity))
                    }
                    if let message {
                        Text(message)
                            .font(.system(size: 20, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(CoverScreensPolicy.clockOpacity))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .frame(maxWidth: 640)
                    }
                    Text(hint)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(
                            .white.opacity(showsHint ? CoverScreensPolicy.hintOpacity : 0)
                        )
                        .animation(.easeOut(duration: 0.8), value: showsHint)
                }
            }
        }
        .ignoresSafeArea()
        .task {
            try? await Task.sleep(for: .seconds(CoverScreensPolicy.hintDuration))
            showsHint = false
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(
                .easeInOut(duration: CoverScreensPolicy.sealBreathDuration)
                    .repeatForever(autoreverses: true)
            ) { inhales = true }
        }
        .accessibilityElement()
        .accessibilityLabel("Screens covered. \(message.map { "\($0). " } ?? "")\(hint)")
    }
}

/// 보조 화면의 가림막: 검정 위 수면을 따라 물범이 천천히 헤엄친다. 머리와 등만 물 위에 보이고,
/// 꼬리로 물을 차며 한 칸씩 오르내린다. 동작 줄이기가 켜져 있으면 가운데에 떠 있기만 한다.
/// 칸 단위로만 그려 픽셀이 흐려지지 않는다.
struct CoverScreensSwimView: View {
    /// 출발점(칸). 화면마다 다르게 준다.
    var startOffset: Double = 0
    /// 한 칸 크기(pt). 큰 외장 모니터에서도 물범이 보이도록 낮잠 화면(6pt)보다 크게.
    var pixelSize: CGFloat = 8
    /// (렌더 도구) 고정 시각. 주면 그 순간 한 장만 그린다.
    var frozenElapsed: TimeInterval?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()

    private static let outline = Color(red: 22 / 255, green: 26 / 255, blue: 48 / 255)
    private static let shade = Color(red: 176 / 255, green: 190 / 255, blue: 216 / 255)
    private static let crest = Color(red: 110 / 255, green: 145 / 255, blue: 255 / 255)
    private static let water = Color(red: 36 / 255, green: 64 / 255, blue: 170 / 255)

    private static func color(_ ink: ChapMascot.Ink) -> Color {
        switch ink {
        case .outline: return outline
        case .body: return .white
        case .shade: return shade
        case .water: return water
        case .crest: return crest
        case .splash: return crest
        }
    }

    var body: some View {
        GeometryReader { geo in
            TimelineView(.periodic(from: start, by: ChapMascot.Swim.frameDuration)) { context in
                let lane = Int(geo.size.width / pixelSize)
                let frame: ChapMascot.SwimFrame =
                    reduceMotion
                    ? ChapMascot.restingSwimFrame(laneCells: lane)
                    : ChapMascot.swimFrame(
                        elapsed: frozenElapsed ?? context.date.timeIntervalSince(start),
                        laneCells: lane, startOffset: startOffset)
                Canvas { canvas, _ in draw(frame, lane: lane, height: geo.size.height, in: canvas) }
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .accessibilityElement()
        .accessibilityLabel("Screens covered")
    }

    private func draw(
        _ frame: ChapMascot.SwimFrame, lane: Int, height: CGFloat, in canvas: GraphicsContext
    ) {
        let level = Int((height / pixelSize * CoverScreensPolicy.swimWaterlineFraction).rounded())
        func cell(_ x: Int, _ y: Int) -> Path {
            Path(
                CGRect(
                    x: CGFloat(x) * pixelSize, y: CGFloat(y) * pixelSize, width: pixelSize,
                    height: pixelSize))
        }
        func surface(_ x: Int) -> Int {
            ChapMascot.surfaceRow(x: x, level: level, phase: frame.wavePhase)
        }
        // 물범: 수면보다 위에 있는 칸만. 스프라이트의 waterline 행이 수면에 오도록 놓는다.
        let top = level - ChapMascot.Swim.waterline + frame.bob
        var seal = canvas
        seal.opacity = CoverScreensPolicy.swimSealOpacity
        for pixel in ChapMascot.pixels(eyes: .open, pose: frame.pose) {
            let x = frame.x + pixel.x
            let y = top + pixel.y
            guard (0..<lane).contains(x), y < surface(x) else { continue }
            seal.fill(cell(x, y), with: .color(Self.color(pixel.ink)))
        }
        // 물: 화면 끝에서 끝까지 물결 한 줄과 그 아래 몇 줄.
        var water = canvas
        water.opacity = CoverScreensPolicy.swimWaterOpacity
        for x in 0..<max(lane, 0) {
            let crest = surface(x)
            water.fill(cell(x, crest), with: .color(Self.crest))
            for y in (crest + 1)...(crest + ChapMascot.Swim.waterRows) {
                water.fill(cell(x, y), with: .color(Self.water))
            }
        }
    }
}
