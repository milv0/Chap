import SwiftUI

// MARK: - Focus (Keep Mac Awake)

/// 노치 한 칸의 Focus 모드. Keep Mac Awake 세션을 번개 아이콘과 함께 켜고 끄며
/// 남은 시간을 크게 보여준다. 상태바 메뉴의 Keep Mac Awake와 같은 세션이다.
struct NotchFocusView: View {
    let palette: NotchWidgetPalette
    /// 도커를 열 때의 세션 종료 시각. 이후 변화는 알림으로 받는다.
    @State var sessionEnd: Date?

    /// 세션을 켜고 끄는 요청. 컨트롤러가 앱의 KeepAwakeController로 전달한다.
    static let activateRequest = Notification.Name("ChapFocusActivate")
    static let deactivateRequest = Notification.Name("ChapFocusDeactivate")

    private var isActive: Bool { (sessionEnd ?? .distantPast) > Date() }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // 켜져 있으면 제목 번개가 진한 블루로 바뀐다(꺼짐은 다른 칸과 같은 연한 블루).
            NotchWidgetHeader(
                symbol: "bolt.fill", title: "Focus",
                palette: isActive ? palette.withIcon(DS.accent) : palette)
            Group {
                if let sessionEnd, sessionEnd > Date() {
                    active(until: sessionEnd)
                } else {
                    idle
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(height: widgetBodyHeight, alignment: .top)
        }
        .onReceive(
            NotificationCenter.default.publisher(for: KeepAwakeController.didChangeNotification)
        ) { note in
            sessionEnd = note.object as? Date
        }
    }

    /// 마지막으로 고른 Focus 길이(초). 다음에 열 때 다이얼이 같은 시간에 있다.
    @AppStorage("ChapFocusPresetDuration") private var storedDuration =
        Double(KeepAwakePolicy.defaultFocusDialHours * 3600)
    @State private var isCenterHovered = false
    /// 다이얼을 끄는 중인지. 그동안만 가운데에 고른 시간("4h")을 보여 준다.
    @State private var isPicking = false

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
            name: Self.activateRequest,
            object: KeepAwakePolicy.focusPreset(hours: dialHours).duration)
    }

    /// 꺼짐: 다이얼을 끌어 시간을 맞추고(1~12시간, 마지막 값 기억), 가운데를 누르면 켠다.
    private var idle: some View {
        FocusDial(
            fraction: KeepAwakePolicy.focusDialFraction(hours: Double(dialHours)),
            isRunning: false, palette: palette, onPick: setDialHours,
            onPickingChange: { picking in
                withAnimation(.easeOut(duration: 0.12)) { isPicking = picking }
            }
        ) {
            // 다이얼 안쪽 원 전체가 켜기 스위치다. 따로 버튼 모양을 두지 않고, 마우스를 올리면 안쪽이 옅게 물든다.
            Button(action: start) {
                // 가운데는 고른 시간 숫자와 그 아래 작은 "On". 숫자가 주인공이다.
                FocusDialInner(isHovered: isCenterHovered, hoverTint: DS.accent.opacity(0.10)) {
                    VStack(spacing: 2) {
                        Text("\(dialHours)h")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(palette.primary)
                        Text(KeepAwakePolicy.focusDialOnLabel)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(DS.accent)
                    }
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
    /// 안쪽 원을 누르면 끈다(마우스를 올리면 "Chap off"가 빨강).
    private func active(until end: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(end.timeIntervalSince(context.date), 0)
            FocusDial(
                fraction: KeepAwakePolicy.focusDialFraction(hours: remaining / 3600),
                isRunning: true, palette: palette, onPick: nil
            ) {
                Button {
                    NotificationCenter.default.post(name: Self.deactivateRequest, object: nil)
                } label: {
                    // 가운데는 남은 시간 숫자와 그 아래 작은 "Off"(마우스를 올리면 빨강).
                    FocusDialInner(
                        isHovered: isCenterHovered, hoverTint: palette.primary.opacity(0.06)
                    ) {
                        VStack(spacing: 2) {
                            Text(KeepAwakePolicy.remainingClockLabel(until: end, now: context.date))
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(palette.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text(KeepAwakePolicy.focusDialOffLabel)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(isCenterHovered ? DS.danger : palette.secondary)
                        }
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

/// 다이얼 안쪽 원(누르는 자리). 호 안쪽을 거의 채우는 원이 통째로 스위치이고, 마우스를 올리면 옅게 물든다.
private struct FocusDialInner<Content: View>: View {
    let isHovered: Bool
    let hoverTint: Color
    @ViewBuilder let content: () -> Content

    /// 호(반지름 44, 두께 6) 안쪽에 6pt 여유를 둔 원.
    static var diameter: CGFloat { 2 * (44 - 3 - 6) }

    var body: some View {
        content()
            // 숫자 + On/Off 두 줄은 원 중심에 그대로 둔다(올리면 숫자가 위로 쏠려 보인다).
            .frame(width: Self.diameter, height: Self.diameter)
            .background(Circle().fill(isHovered ? hoverTint : Color.clear))
            .contentShape(Circle())
            .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

/// Focus 다이얼. 반원보다 긴 240° 호가 위를 감싸고 아래는 평평하게 열려 있다(속도계처럼).
/// - 꺼짐: 연한 트랙 위에 고른 시간까지 블루 호 + 끝에 손잡이. 호(테두리 띠)를 끌면 1시간 단위로 맞춘다.
/// - 켜짐: 같은 눈금에서 남은 시간까지 블루 호가 1초마다 줄어든다(끌 수 없음).
/// 눈금은 3·6·9시간에 짧은 점, 양 끝 아래에 "0"과 "12h".
private struct FocusDial<Center: View>: View {
    let fraction: Double
    let isRunning: Bool
    let palette: NotchWidgetPalette
    /// nil이면 끌어서 바꿀 수 없다(켜짐).
    let onPick: ((Int) -> Void)?
    /// 호를 끄기 시작하고 끝낼 때 알린다.
    var onPickingChange: (Bool) -> Void = { _ in }
    @ViewBuilder let center: () -> Center

    static var size: CGSize { CGSize(width: 104, height: 92) }
    static var lineWidth: CGFloat { 6 }
    /// 원 반지름. 호 아래 빈 곳(120°)이 칸 바닥에 닿지 않도록 중심을 조금 위에 둔다.
    static var radius: CGFloat { 44 }
    static var centerPoint: CGPoint { CGPoint(x: size.width / 2, y: radius + lineWidth / 2 + 1) }

    private var sweep: Double { KeepAwakePolicy.focusDialSweep }
    /// SwiftUI 각도(3시 = 0°, 시계 방향 +). 호는 12시에서 -120°(왼쪽 아래)부터 +120°(오른쪽 아래)까지.
    private var startAngle: Angle { .degrees(-90 - sweep / 2) }

    private func arc(to fraction: Double) -> Path {
        var path = Path()
        path.addArc(
            center: Self.centerPoint, radius: Self.radius, startAngle: startAngle,
            endAngle: startAngle + .degrees(sweep * fraction), clockwise: false)
        return path
    }

    private func point(at fraction: Double, radius: CGFloat) -> CGPoint {
        let angle = (startAngle + .degrees(sweep * fraction)).radians
        return CGPoint(
            x: Self.centerPoint.x + radius * CGFloat(cos(angle)),
            y: Self.centerPoint.y + radius * CGFloat(sin(angle)))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            arc(to: 1)
                .stroke(
                    palette.primary.opacity(0.12),
                    style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round))
            if fraction > 0 {
                arc(to: fraction)
                    .stroke(
                        DS.accent, style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round)
                    )
                    .animation(
                        isRunning ? .linear(duration: 1) : .smooth(duration: 0.12), value: fraction)
            }
            // 눈금: 3·6·9시간(양 끝은 아래 0·12h 글자가 맡는다).
            ForEach(1..<4, id: \.self) { index in
                Circle()
                    .fill(palette.secondary.opacity(0.6))
                    .frame(width: 2, height: 2)
                    .position(
                        point(at: Double(index) / 4, radius: Self.radius - Self.lineWidth - 3))
            }
            if !isRunning {
                Circle()
                    .fill(.white)
                    .overlay(Circle().strokeBorder(DS.accent, lineWidth: 2))
                    .frame(width: 12, height: 12)
                    .shadow(color: .black.opacity(0.2), radius: 1.5, y: 0.5)
                    .position(point(at: fraction, radius: Self.radius))
                    .animation(.smooth(duration: 0.12), value: fraction)
            }
            Text("0")
                .position(x: point(at: 0, radius: Self.radius).x, y: Self.size.height - 5)
            Text("12h")
                .position(x: point(at: 1, radius: Self.radius).x, y: Self.size.height - 5)
            center()
                .position(x: Self.centerPoint.x, y: Self.centerPoint.y)
        }
        .font(.system(size: 9, weight: .medium))
        .foregroundColor(palette.secondary)
        .frame(width: Self.size.width, height: Self.size.height)
        .contentShape(Rectangle())
        // 호(테두리 띠) 위에서 시작한 끌기만 시간을 바꾼다. 가운데 버튼의 클릭은 그대로 버튼이 받는다.
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    guard let onPick else { return }
                    let start = value.startLocation
                    let distance = hypot(start.x - Self.centerPoint.x, start.y - Self.centerPoint.y)
                    guard distance > Self.radius - 16 else { return }
                    onPickingChange(true)
                    onPick(
                        KeepAwakePolicy.focusDialHours(
                            dx: Double(value.location.x - Self.centerPoint.x),
                            dy: Double(value.location.y - Self.centerPoint.y)))
                }
                .onEnded { _ in onPickingChange(false) },
            including: onPick == nil ? .subviews : .all
        )
        // 제목 줄과 호 꼭대기 사이 숨 쉴 틈. 끌기 좌표는 이 여백 안쪽 다이얼 기준 그대로다.
        .padding(.top, Self.topGap)
    }

    /// 제목과 호 꼭대기 사이 간격. 다이얼(92pt) + 간격이 칸 본문 높이(113pt) 안에 들어간다.
    static var topGap: CGFloat { 9 }
}

/// 누르는 순간 살짝 눌렸다 튀어 오르는 버튼 모양. "딱" 누르는 손맛을 준다.
private struct FocusPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .animation(
                .spring(response: 0.22, dampingFraction: 0.55), value: configuration.isPressed)
    }
}
