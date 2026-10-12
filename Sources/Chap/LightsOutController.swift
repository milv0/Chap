import AppKit
import IOKit.pwr_mgt
import SwiftUI

/// Lights Out: 자리를 비울 때 모든 화면을 검정으로 덮는 가림막.
///
/// **잠금이 아니다.** 비밀번호를 묻지 않고, Chap이 끝나면 걷힌다. 어깨너머 시선을 가리는
/// 용도이며 진짜 보안은 macOS 화면 잠금(⌃⌘Q)이 맡는다.
///
/// 입력: 덮여 있는 동안 Chap이 키 포커스를 갖는다. 다른 앱이 활성화되면(⌘Tab 등) 곧바로 되찾는다.
/// 그래도 키가 다른 앱으로 간 경우를 위해 전역 키 모니터(접근성 권한이 있을 때)로 해제 키와
/// 연타를 계속 본다 — 해제 경로가 포커스에 매이지 않게 하기 위해서다(FLOW I19).
///
/// Keep Mac Awake와 독립이다. 가림막은 켜져 있는 동안 자기 몫의 IOKit 어써션을 들기 때문에,
/// Keep Awake가 꺼져 있어도 화면이 꺼지지 않고, Keep Awake 세션이 끝나도 가림막은 그대로다.
/// 상태는 메모리에만 있다(다음 실행은 늘 꺼진 상태로 시작한다). 메인 스레드 전제이며,
/// AppDelegate(메인 스레드)에서만 호출한다.
final class LightsOutController {
    /// 켜지거나 꺼질 때 메뉴를 다시 그리도록 알린다.
    static let didChangeNotification = Notification.Name("ChapLightsOutDidChange")

    private var windows: [NSWindow] = []
    private var assertionID = IOPMAssertionID(0)
    private var hasAssertion = false
    private var keyMonitor: Any?
    /// Chap이 키 포커스를 잃었을 때도 해제 키·연타를 보는 전역 모니터 (접근성 권한 필요, 삼키지 못함).
    private var globalKeyMonitor: Any?
    private var screenObserver: NSObjectProtocol?
    private var resignObserver: NSObjectProtocol?
    /// 켜기 직전 앞에 있던 앱. 걷은 뒤 그 앱으로 돌려준다(안 그러면 입력이 창 없는 Chap에 간다).
    private var previousApp: NSRunningApplication?
    /// 비상 해제 판정용 최근 키 입력 시각.
    private var recentPresses: [Date] = []
    /// 해제 키를 읽는다. AppDelegate가 config를 넘겨준다.
    var unlockKeyProvider: () -> String = { LightsOutPolicy.escapeKey }

    private(set) var isOn = false

    func toggle() { isOn ? turnOff() : turnOn() }

    func turnOn() {
        guard !isOn else { return }
        isOn = true
        recentPresses = []
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
            guard let self, self.isOn, let first = self.windows.first else { return }
            NSApp.activate(ignoringOtherApps: true)
            first.makeKeyAndOrderFront(nil)
        }
    }

    // MARK: - 화면

    /// 화면마다 창을 하나씩. 첫 창만 key가 되어 입력을 받고, 나머지는 덮기만 한다.
    private func installWindows() {
        windows.forEach { $0.orderOut(nil) }
        windows = NSScreen.screens.enumerated().map { index, screen in
            let window = LightsOutWindow(
                contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.setFrame(screen.frame, display: true)
            // 노치 도커(.statusBar)와 HUD보다 위에 와야 아무것도 비치지 않는다.
            window.level = .screenSaver
            window.isOpaque = true
            window.backgroundColor = .black
            window.hasShadow = false
            window.ignoresMouseEvents = false
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
            window.contentView = NSHostingView(
                rootView: LightsOutView(
                    showsClock: index == 0,
                    hint: LightsOutPolicy.hint(
                        unlockKey: unlockKeyProvider())))
            window.orderFrontRegardless()
            return window
        }
        guard let first = windows.first else { return }
        NSApp.activate(ignoringOtherApps: true)
        first.makeKeyAndOrderFront(nil)
    }

    // MARK: - 입력

    /// 가림막이 떠 있는 동안의 키 입력. 해제 키 또는 빠른 연타면 걷고, 그 외에는 삼킨다
    /// (가려진 앱에 눈먼 입력이 들어가지 않게).
    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isOn else { return event }
            self.handleKeyDown(event)
            return nil
        }
        // 다른 앱이 키를 가져간 경우의 대비. 접근성 권한이 없으면 아무것도 오지 않을 뿐 해롭지 않다.
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) {
            [weak self] event in
            guard let self, self.isOn else { return }
            self.handleKeyDown(event)
            self.reclaimFocus()
        }
    }

    /// 키 하나를 처리한다. 걷었으면 true. (테스트에서 직접 부른다.)
    @discardableResult
    func handleKeyDown(_ event: NSEvent, now: Date = Date()) -> Bool {
        if LightsOutPolicy.unlocks(
            isEscape: event.keyCode == 53, characters: event.charactersIgnoringModifiers,
            unlockKey: unlockKeyProvider())
        {
            turnOff()
            return true
        }
        // 해제 키를 잊었을 때: 아무 키나 빠르게 다섯 번. 누르고 있는 자동 반복은 세지 않는다.
        guard LightsOutPolicy.countsAsPress(isRepeat: event.isARepeat) else { return false }
        recentPresses = LightsOutPolicy.recentPresses(recentPresses + [now], now: now)
        guard LightsOutPolicy.isRapidEscape(presses: recentPresses, now: now) else { return false }
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
            "Chap Lights Out" as CFString,
            &id)
        guard result == kIOReturnSuccess else {
            // 어써션이 없으면 화면이 꺼질 수 있다. 가림막 자체는 그대로 둔다.
            Log.app.error("Lights Out assertion failed: \(result, privacy: .public)")
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
final class LightsOutWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    /// 클릭은 삼킨다. 가려진 앱이 눈먼 클릭을 받지 않게.
    override func mouseDown(with event: NSEvent) {}
}

/// 가림막 내용: 검정 바탕에 자는 물범, 시간, 그리고 잠깐 떴다 사라지는 안내.
/// (개발용) 렌더 도구가 모습을 PNG로 뽑을 때도 쓴다.
struct LightsOutView: View {
    /// 주 화면에만 시간과 안내를 둔다. 나머지 화면은 검정만.
    let showsClock: Bool
    let hint: String

    @State private var showsHint = true

    var body: some View {
        ZStack {
            Color.black
            if showsClock {
                VStack(spacing: 24) {
                    // HUD와 같은 자는 물범. 불을 끈 화면이라 아주 흐리게 둔다.
                    Image(
                        nsImage: ChapMascotImage.image(
                            pixelSize: 6, eyes: .closed, pose: .rest, showsSleepZ: true)
                    )
                    .opacity(0.22)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(context.date, format: .dateTime.hour().minute())
                            .font(.system(size: 64, weight: .thin, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(.white.opacity(0.26))
                    }
                    Text(hint)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(showsHint ? 0.3 : 0))
                        .animation(.easeOut(duration: 0.8), value: showsHint)
                }
            }
        }
        .ignoresSafeArea()
        .task {
            try? await Task.sleep(for: .seconds(LightsOutPolicy.hintDuration))
            showsHint = false
        }
        .accessibilityElement()
        .accessibilityLabel("Lights out. \(hint)")
    }
}
