import SwiftUI

// MARK: - Focus (Keep Mac Awake · Timer)

/// 노치 한 칸의 Focus. 다이얼 하나로 Keep Mac Awake 세션(1~12시간)이나 타이머(5~60분)를 켠다.
/// 제목 줄의 번개·타이머 아이콘으로 모드를 바꾸고, 마지막 모드를 기억한다. 둘 다 상태바 메뉴의
/// Keep Mac Awake·Timer와 같은 세션이다.
struct NotchFocusView: View {
    let palette: NotchWidgetPalette
    /// 도커를 열 때의 세션 종료 시각. 이후 변화는 알림으로 받는다.
    @State private var sessionEnd: Date?
    /// 도커를 열 때 돌고 있던 타이머가 끝나는 시각. 이후 변화는 알림으로 받는다.
    @State private var timerEnd: Date?
    @State private var mode: FocusDialMode
    /// 모드를 바꿀 때 본문이 밀려 나가는 방향과 끝에서 튕기는 양(Launchers·Apps 탭 칸과 같은 움직임).
    @State private var motion = NotchTabMotion()

    private static let modeIDs = FocusDialMode.allCases.map(\.rawValue)

    /// Keep Mac Awake 세션을 켜고 끄는 요청. 컨트롤러가 앱의 KeepAwakeController로 전달한다.
    static let activateRequest = Notification.Name("ChapFocusActivate")
    static let deactivateRequest = Notification.Name("ChapFocusDeactivate")
    /// 타이머 시작·중지 요청. AppDelegate가 `ChapTimerController`로 전달한다. 시작 object는 길이(초).
    static let timerStartRequest = Notification.Name("ChapTimerStartRequest")
    static let timerStopRequest = Notification.Name("ChapTimerStopRequest")

    /// 오프스크린 렌더에서 보여 줄 모드. nil이면 평소 규칙을 따른다.
    static var previewMode: FocusDialMode?

    init(palette: NotchWidgetPalette, sessionEnd: Date?, timerEnd: Date?) {
        self.palette = palette
        _sessionEnd = State(initialValue: sessionEnd)
        _timerEnd = State(initialValue: timerEnd)
        let now = Date()
        _mode = State(
            initialValue: Self.previewMode
                ?? FocusDialMode.initial(
                    stored: UserDefaults.standard.string(forKey: FocusDialMode.storageKey),
                    isFocusRunning: (sessionEnd ?? .distantPast) > now,
                    isTimerRunning: (timerEnd ?? .distantPast) > now))
    }

    private func isRunning(_ mode: FocusDialMode) -> Bool {
        switch mode {
        case .focus: return (sessionEnd ?? .distantPast) > Date()
        case .timer: return (timerEnd ?? .distantPast) > Date()
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            header
            Group {
                switch mode {
                case .focus: NotchFocusAwakeBody(palette: palette, sessionEnd: sessionEnd)
                case .timer: NotchFocusTimerBody(palette: palette, endDate: timerEnd)
                }
            }
            .id(mode)
            .transition(motion.transition)
            .offset(x: motion.nudge)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(height: widgetBodyHeight, alignment: .top)
        }
        // 트랙패드 두 손가락 가로 스와이프로 Focus ↔ Timer. 다이얼의 호 끌기는 클릭 드래그라 섞이지 않는다.
        .tabSwipe(enabled: true) { step in
            NotchTabMotion.step(
                step, current: mode.rawValue, ids: Self.modeIDs, motion: $motion, apply: apply)
        }
        .onReceive(
            NotificationCenter.default.publisher(for: KeepAwakeController.didChangeNotification)
        ) { note in
            sessionEnd = note.object as? Date
        }
        .onReceive(
            NotificationCenter.default.publisher(for: ChapTimerController.didChangeNotification)
        ) { note in
            timerEnd = note.object as? Date
        }
    }

    /// 모드를 바꾸고 마지막 모드로 기억한다(클릭·스와이프 공통).
    private func apply(_ id: String) {
        guard let next = FocusDialMode(rawValue: id) else { return }
        mode = next
        UserDefaults.standard.set(next.rawValue, forKey: FocusDialMode.storageKey)
    }

    // MARK: - Header (모드 전환)

    /// 고른 모드는 아이콘과 제목, 다른 모드는 아이콘만. 다른 모드가 돌고 있으면 아이콘 옆에 작은 점.
    private var header: some View {
        HStack(spacing: 0) {
            ForEach(FocusDialMode.allCases, id: \.self) { item in
                modeTab(item)
            }
        }
    }

    private func modeTab(_ item: FocusDialMode) -> some View {
        let isSelected = item == mode
        let running = isRunning(item)
        return Button {
            guard !isSelected else { return }
            NotchTabMotion.select(
                item.rawValue, from: mode.rawValue, ids: Self.modeIDs, motion: $motion,
                apply: apply)
        } label: {
            Group {
                if isSelected {
                    // 돌고 있으면 제목 아이콘이 진한 블루로 바뀐다(꺼짐은 다른 칸과 같은 연한 블루).
                    NotchWidgetHeader(
                        symbol: item.symbol, title: item.title,
                        palette: running ? palette.withIcon(DS.accent) : palette)
                } else {
                    Image(systemName: item.symbol)
                        .font(DS.notchLabel)
                        .foregroundColor(running ? DS.accent : palette.heading.opacity(0.45))
                        .overlay(alignment: .topTrailing) {
                            if running {
                                Circle().fill(DS.accent).frame(width: 4, height: 4)
                                    .offset(x: 3, y: -1)
                            }
                        }
                        .padding(.horizontal, 6)
                        .frame(height: DS.notchHeaderHeight)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(isSelected ? item.title : "Switch to \(item.title)")
        .accessibilityLabel(item.title)
        .accessibilityValue(running ? "On" : "")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Focus 모드 (Keep Mac Awake)

/// Focus 모드 본문. 다이얼로 1~12시간을 고르고 가운데를 눌러 Keep Mac Awake를 켠다.
struct NotchFocusAwakeBody: View {
    let palette: NotchWidgetPalette
    let sessionEnd: Date?

    /// 마지막으로 고른 Focus 길이(초). 다음에 열 때 다이얼이 같은 시간에 있다.
    @AppStorage("ChapFocusPresetDuration") private var storedDuration =
        Double(KeepAwakePolicy.defaultFocusDialHours * 3600)
    @State private var isCenterHovered = false

    private var dialHours: Int { KeepAwakePolicy.focusDialHours(forStoredDuration: storedDuration) }

    private func setDialHours(_ hours: Int) {
        guard hours != dialHours else { return }
        // 한 칸 넘어갈 때마다 트랙패드가 똑 하고 눈금을 알려 준다.
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        storedDuration = Double(hours * 3600)
    }

    private func start() {
        // 트랙패드가 "딱" 하고 눌린 느낌을 준다 (권한 없음, 트랙패드가 없으면 아무 일 없음).
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        NotificationCenter.default.post(
            name: NotchFocusView.activateRequest,
            object: KeepAwakePolicy.focusPreset(hours: dialHours).duration)
    }

    var body: some View {
        if let sessionEnd, sessionEnd > Date() {
            active(until: sessionEnd)
        } else {
            idle
        }
    }

    /// 꺼짐: 다이얼을 끌어 시간을 맞추고(1~12시간, 마지막 값 기억), 가운데를 누르면 켠다.
    private var idle: some View {
        FocusDial(
            fraction: KeepAwakePolicy.focusDialFraction(hours: Double(dialHours)),
            isRunning: false, palette: palette, maxLabel: "12h",
            onPick: { setDialHours(KeepAwakePolicy.focusDialHours(fraction: $0)) }
        ) {
            // 다이얼 안쪽 원 전체가 켜기 스위치다. 따로 버튼 모양을 두지 않고, 마우스를 올리면 안쪽이 옅게 물든다.
            Button(action: start) {
                FocusDialInner(isHovered: isCenterHovered, hoverTint: DS.accent.opacity(0.10)) {
                    FocusDialCenterLabel(
                        value: "\(dialHours)h", caption: KeepAwakePolicy.focusDialOnLabel,
                        valueSize: 20, valueColor: palette.primary, captionColor: DS.accent)
                }
            }
            .buttonStyle(FocusPressStyle())
            .onHover { isCenterHovered = $0 }
            .help("Keep your Mac awake for \(dialHours) h. Drag the dial to change.")
            .accessibilityLabel("Turn on for \(dialHours) hours")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Focus length")
        .accessibilityValue("\(dialHours) hours")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                setDialHours(min(dialHours + 1, KeepAwakePolicy.focusDialHours.upperBound))
            case .decrement:
                setDialHours(max(dialHours - 1, KeepAwakePolicy.focusDialHours.lowerBound))
            @unknown default: break
            }
        }
    }

    /// 켜짐: 같은 다이얼에서 남은 시간만큼의 호가 줄어들고(같은 0~12시간 눈금), 가운데에 남은 시간.
    /// 안쪽 원을 누르면 끈다(마우스를 올리면 "Off"가 빨강).
    private func active(until end: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(end.timeIntervalSince(context.date), 0)
            FocusDial(
                fraction: KeepAwakePolicy.focusDialFraction(hours: remaining / 3600),
                isRunning: true, palette: palette, maxLabel: "12h", onPick: nil
            ) {
                Button {
                    NotificationCenter.default.post(
                        name: NotchFocusView.deactivateRequest, object: nil)
                } label: {
                    FocusDialInner(
                        isHovered: isCenterHovered, hoverTint: palette.primary.opacity(0.06)
                    ) {
                        FocusDialCenterLabel(
                            value: KeepAwakePolicy.remainingClockLabel(
                                until: end, now: context.date),
                            caption: KeepAwakePolicy.focusDialOffLabel, valueSize: 15,
                            valueColor: palette.primary,
                            captionColor: isCenterHovered ? DS.danger : palette.secondary)
                    }
                }
                .buttonStyle(FocusPressStyle())
                .onHover { isCenterHovered = $0 }
                .help("Turn off Keep Mac Awake")
                .accessibilityLabel(
                    "Focus on, \(KeepAwakePolicy.remainingLabel(until: end, now: context.date)) left"
                )
                .accessibilityHint("Turns Focus off")
            }
        }
    }
}
