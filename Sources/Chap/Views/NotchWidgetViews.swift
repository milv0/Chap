import AVFoundation
import SwiftUI

/// 노치 위젯이 공유하는 전경 색 묶음. 패널 스타일(Custom/Glass)에 맞춰 계산된 값을 받는다.
struct NotchWidgetPalette {
    let primary: Color
    let secondary: Color
    let accent: Color
    /// 섹션 제목·아이콘 색.
    let heading: Color
    let textShadowOpacity: Double
    let hoverBackground: Color
    let subtleSurface: Color
    /// 제목 아이콘 색 (연한 대표 블루). nil이면 제목 색을 쓴다.
    var icon: Color? = nil

    /// 제목 아이콘 색만 바꾼 사본 (Focus가 켜지면 진한 블루).
    func withIcon(_ color: Color) -> NotchWidgetPalette {
        var copy = self
        copy.icon = color
        return copy
    }
}

/// 위젯 칸 상단의 아이콘+제목 줄. 런처 섹션 제목과 같은 모양이다.
struct NotchWidgetHeader: View {
    let symbol: String
    let title: String
    let palette: NotchWidgetPalette

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(DS.notchLabel)
                .foregroundColor(palette.icon ?? palette.heading)
            Text(title)
                .font(DS.notchLabel)
                .foregroundColor(palette.heading)
        }
        .shadow(color: .black.opacity(palette.textShadowOpacity), radius: 1.5, y: 0.5)
        .padding(.horizontal, 6)
        .frame(height: DS.notchHeaderHeight)
        .accessibilityAddTraits(.isHeader)
    }
}

/// 위젯 본문 높이. 목록 칸 4줄과 정확히 같아 모든 칸의 바닥선이 맞는다.
private let widgetBodyHeight: CGFloat = NotchAppIconTile.listBodyHeight

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
            .accessibilityLabel("Chap on for \(dialHours) hours")
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
                .help(
                    "\(KeepAwakePolicy.remainingClockLabel(until: end, now: context.date)) left. "
                        + "Click to turn off."
                )
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
            // 아래가 열린 호라 보이는 호의 가운데가 원 중심보다 위에 있다. 글자를 조금 올려 눈으로 가운데에 맞춘다.
            .offset(y: -4)
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

// MARK: - Mirror

/// 상단 검정 띠의 거울 아이콘과, 누르면 띠 바로 아래로 펼쳐지는 좌우 반전 미리보기.
/// 아이콘은 Drop 배지 오른쪽에 두고, 배지가 없으면(보관 파일 없음) 배지 자리에 둔다.
/// 켜기 전에는 카메라를 쓰지 않고, ×·아이콘 재클릭·도커 닫힘으로 꺼진다.
struct NotchMirrorStripControl: View {
    /// 패널 좌표의 아이콘 중심 x.
    let iconCenterX: CGFloat
    let stripHeight: CGFloat
    /// 한 번에 하나의 띠 도구만 펼친다. 컨테이너가 소유한다.
    @Binding var isOpen: Bool

    @State private var state = MirrorCamera.displayState
    @State private var isHovered = false

    /// 펼친 미리보기 크기. 얼굴 확인용이라 세로가 약간 긴 4:3에 가깝게 좁힌다
    /// (가로 144, 원본이 넓으면 aspect fill로 좌우를 잘라 얼굴이 가운데 남는다).
    static let previewSize = CGSize(width: 144, height: 108)
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                stripButton
                    .position(x: iconCenterX, y: stripHeight / 2)
                if isOpen && state == .live {
                    preview
                        .position(
                            NotchLauncherPolicy.stripPopupCenter(
                                iconCenterX: iconCenterX, popupSize: Self.previewSize,
                                containerWidth: geo.size.width, stripHeight: stripHeight)
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .top)))
                }
            }
        }
        .animation(.smooth(duration: 0.18), value: isOpen)
        .onAppear { state = MirrorCamera.displayState }
        .onDisappear { turnOff() }
        // 다른 도구가 열리며 닫히면 카메라도 끈다.
        .onChange(of: isOpen) { _, open in
            if !open { MirrorCamera.shared.stop() }
        }
    }

    private var stripButton: some View {
        Button(action: tapped) {
            Image(systemName: symbol)
                .font(DS.notchStripIconFont)
                .foregroundColor(isOpen ? DS.accent : DS.notchStripIconColor(isHovered: isHovered))
                .frame(width: NotchLauncherPolicy.stripToolPitch, height: stripHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(state == .restricted || state == .noCamera)
        .onHover { isHovered = $0 }
        .help(helpText)
        .accessibilityLabel(isOpen ? "Turn off Mirror" : "Mirror")
        .accessibilityHint(helpText)
    }

    private var preview: some View {
        MirrorPreview(camera: MirrorCamera.shared)
            .frame(width: Self.previewSize.width, height: Self.previewSize.height)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
            .overlay(alignment: .topTrailing) {
                Button(action: turnOff) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(.black.opacity(0.5)))
                }
                .buttonStyle(.plain)
                .padding(6)
                .accessibilityLabel("Turn off Mirror")
            }
            .accessibilityLabel("Camera mirror preview")
    }

    private var symbol: String {
        switch state {
        case .live, .needsPermission: return "web.camera"
        case .denied, .restricted, .noCamera: return "video.slash"
        }
    }

    private var helpText: String {
        switch state {
        case .live, .needsPermission:
            return isOpen ? "Turn off Mirror" : "Mirror: check your camera"
        case .denied: return "Camera access is off. Click to open Privacy settings"
        case .restricted: return "Camera access is restricted on this Mac"
        case .noCamera: return "No camera is connected"
        }
    }

    private func tapped() {
        state = MirrorCamera.displayState
        switch state {
        case .live:
            isOpen ? turnOff() : turnOn()
        case .needsPermission:
            // 처음 누를 때만 권한을 묻고, 허용하면 바로 켠다.
            MirrorCamera.requestAccess { granted in
                state = MirrorCamera.displayState
                if granted { turnOn() }
            }
        case .denied:
            if let url = URL(
                string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")
            {
                NSWorkspace.shared.open(url)
            }
        case .restricted, .noCamera:
            break
        }
    }

    /// 미리보기를 보여주기만 한다. 캡처 시작은 미리보기가 세션에 연결된 뒤
    /// `MirrorPreview`가 한다 (연결 전에 시작하면 크래시).
    private func turnOn() {
        guard MirrorPolicy.shouldCapture(state: state, isTurnedOn: true, isPanelOpen: true)
        else { return }
        isOpen = true
    }

    private func turnOff() {
        isOpen = false
        MirrorCamera.shared.stop()
    }
}

/// 상단 검정 띠 오른쪽의 도구 아이콘 묶음 (Mirror, Quick Note). Drop 배지가 있으면 그 오른쪽,
/// 없으면 배지 자리부터 28pt 간격으로 나란히 두고, 한 번에 하나만 띠 아래로 펼친다.
struct NotchStripTools: View {
    /// 패널 가운데에서 노치 오른쪽 끝까지의 거리 (노치 반폭).
    let notchRightEdge: CGFloat
    let stripHeight: CGFloat
    let besideDropBadge: Bool
    /// 보관 파일이 없어 Drop 배지 창이 없을 때, 도커가 열린 동안만 같은 자리에 빈 상자
    /// 아이콘을 그린다 (숫자 배지 없이). 접힌 노치에서는 그리지 않는다.
    var showsEmptyDropBox = false
    let showsMirror: Bool
    let showsNote: Bool
    /// Quick Note 아이콘이 켜고 끄는 도커 메모 모드.
    @Binding var isNoteMode: Bool

    private enum Tool: Equatable { case mirror, note }
    @State private var openTool: Tool?

    var body: some View {
        let tools: [Tool] = (showsMirror ? [.mirror] : []) + (showsNote ? [.note] : [])
        let offsets = NotchLauncherPolicy.stripToolCenterOffsets(
            besideDropBadge: besideDropBadge, count: tools.count)
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                if showsEmptyDropBox {
                    // Drop 배지와 같은 아이콘·크기·광학 위치 (배지 아이콘은 본체 중앙에서 왼쪽 4pt, 아래 1pt).
                    Image(systemName: "tray.fill")
                        .font(DS.notchStripIconFont)
                        .foregroundColor(DS.notchStripIconColor())
                        .frame(width: NotchLauncherPolicy.stripToolPitch, height: stripHeight)
                        .position(
                            x: geo.size.width / 2 + notchRightEdge
                                + NotchLauncherPolicy.dropBadgeIconCenterOffset,
                            y: stripHeight / 2 + 1
                        )
                        .help("Drop files on the notch to keep them in Chap Drop")
                        .accessibilityLabel("Chap Drop: empty")
                }
                ForEach(Array(tools.enumerated()), id: \.offset) { index, tool in
                    let centerX = geo.size.width / 2 + notchRightEdge + offsets[index]
                    switch tool {
                    case .mirror:
                        NotchMirrorStripControl(
                            iconCenterX: centerX, stripHeight: stripHeight,
                            isOpen: binding(for: .mirror))
                    case .note:
                        NotchQuickNoteStripButton(
                            iconCenterX: centerX, stripHeight: stripHeight,
                            isNoteMode: $isNoteMode)
                    }
                }
            }
            // 팝업 바깥을 누르거나 패널이 key를 잃으면 접는다.
            .onReceive(
                NotificationCenter.default.publisher(for: NotchLauncherController.didClickPanel)
            ) {
                note in
                guard let open = openTool, let index = tools.firstIndex(of: open) else { return }
                guard let click = note.userInfo?["point"] as? CGPoint else {
                    openTool = nil
                    return
                }
                // 클릭 위치를 이 오버레이의 좌표로 옮긴 뒤, 같은 좌표의 팝업 영역과 비교한다.
                let origin = geo.frame(in: .global).origin
                let local = CGPoint(x: click.x - origin.x, y: click.y - origin.y)
                // 팝업으로 뜨는 도구는 Mirror뿐이다 (Quick Note는 도커 메모 모드로 펼친다).
                let size = NotchMirrorStripControl.previewSize
                let center = NotchLauncherPolicy.stripPopupCenter(
                    iconCenterX: geo.size.width / 2 + notchRightEdge + offsets[index],
                    popupSize: size, containerWidth: geo.size.width, stripHeight: stripHeight)
                let popupFrame = CGRect(
                    x: center.x - size.width / 2, y: center.y - size.height / 2,
                    width: size.width, height: size.height)
                if NotchLauncherPolicy.shouldCollapseStripPopup(
                    click: local, popupFrame: popupFrame, stripHeight: stripHeight)
                {
                    openTool = nil
                }
            }
        }
    }

    private func binding(for tool: Tool) -> Binding<Bool> {
        Binding(
            get: { openTool == tool },
            set: { open in openTool = open ? tool : (openTool == tool ? nil : openTool) })
    }
}

/// 상단 띠의 Quick Note 아이콘. 누르면 위젯 줄 자리가 넓은 메모장으로 바뀐다(메모 모드).
/// 메모를 창으로 분리해 둔 상태면 그 창을 앞으로 가져온다.
struct NotchQuickNoteStripButton: View {
    let iconCenterX: CGFloat
    let stripHeight: CGFloat
    @Binding var isNoteMode: Bool

    @State private var isHovered = false

    var body: some View {
        Button {
            if QuickNoteWindow.isOpen {
                QuickNoteWindow.show()
                NotificationCenter.default.post(
                    name: NotchLauncherController.requestClose, object: nil)
            } else {
                isNoteMode.toggle()
            }
        } label: {
            Image(systemName: "note.text")
                .font(DS.notchStripIconFont)
                .foregroundColor(
                    isNoteMode ? DS.accent : DS.notchStripIconColor(isHovered: isHovered)
                )
                .frame(width: NotchLauncherPolicy.stripToolPitch, height: stripHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(isNoteMode ? "Back to widgets" : "Quick Note")
        .accessibilityLabel(isNoteMode ? "Close Quick Note" : "Quick Note")
        .position(x: iconCenterX, y: stripHeight / 2)
    }
}

/// 좌우 반전된 카메라 미리보기 레이어. 세션 연결은 카메라 큐에서 하고,
/// 연결이 끝난 뒤에만 캡처를 시작한다 (연결과 시작이 겹치면 AVFoundation이 앱을 종료한다).
private struct MirrorPreview: NSViewRepresentable {
    let camera: MirrorCamera

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        // 세션 없이 만든 뒤 카메라 큐에서 연결한다.
        let layer = AVCaptureVideoPreviewLayer()
        layer.videoGravity = .resizeAspectFill
        view.layer = layer
        camera.attach(layer) {
            // 거울처럼 보이도록 좌우를 뒤집는다. connection은 세션 연결 뒤에 생긴다.
            if let connection = layer.connection, connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = true
            }
            camera.start()
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    static func dismantleNSView(_ nsView: NSView, coordinator: ()) {
        MirrorCamera.shared.stop()
    }
}

// MARK: - Quick Note

/// 넓게 펼친 메모(도커 메모 모드, 분리 창)의 상단 도구 줄 동작.
struct NotchQuickNoteToolbar {
    /// 메모를 떠 있는 창으로 분리한다. nil이면 버튼을 숨긴다(이미 창인 경우).
    var onDetach: (() -> Void)?
    /// 메모 모드를 닫고 위젯으로 돌아간다. nil이면 버튼을 숨긴다.
    var onClose: (() -> Void)?
}

/// 노치에서 바로 적는 한 장짜리 메모. 입력은 잠시 멈추면 저장되고,
/// 칸이 사라질 때 남은 변경을 즉시 저장한다.
struct NotchQuickNoteView: View {
    /// 대기 중인 저장을 즉시 쓰라는 요청 (분리 창 닫힘, 앱 종료).
    static let flushRequest = Notification.Name("ChapQuickNoteFlush")

    /// 대기 중인 저장이 파일에 다 쓰일 때까지 기다린다 (앱 종료 직전).
    static func drainPendingSaves() {
        saveQueue.sync {}
    }

    let palette: NotchWidgetPalette
    var showsHeader = true
    var bodyHeight: CGFloat = widgetBodyHeight
    /// 띠에서 펼칠 때는 바로 입력할 수 있게 커서를 넣는다.
    var focusesOnAppear = false
    /// 넓은 메모의 도구 줄(제목·글자 수·복사·분리·닫기). 주면 헤더 대신 그린다.
    var toolbar: NotchQuickNoteToolbar?

    @State private var didCopy = false

    @State private var text = ""
    @State private var didLoad = false
    @State private var lastSaved: Date?
    /// 입력 뒤 아직 파일에 쓰이지 않은 변경이 있는지. 있으면 저장 표시 대신 "Editing"을 보여 준다.
    @State private var hasPendingEdit = false
    /// 메모 상자의 화면 위치(창 콘텐츠 좌표). 상자 밖 클릭이면 커서를 풀고 바로 저장한다.
    @State private var editorFrame: CGRect = .zero
    @FocusState private var isFocused: Bool
    private let store = QuickNoteStore()
    /// @State로 보관해 뷰 구조체가 다시 만들어져도 대기 중인 저장이 취소되지 않는다.
    @State private var debouncer = SaveDebouncer(delay: 0.5)
    /// 저장 순서를 보장하는 직렬 큐. 늦게 끝난 옛 저장이 새 내용을 덮지 않는다.
    private static let saveQueue = DispatchQueue(
        label: "com.mingyupark.Chap.quicknote", qos: .utility)

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let toolbar {
                toolbarRow(toolbar)
            } else if showsHeader {
                NotchWidgetHeader(symbol: "note.text", title: "Quick Note", palette: palette)
            }
            // 목록 본문과 같은 13pt. 회색 상자 대신 옅은 테두리만 두고,
            // 저장 시각은 상자 안 오른쪽 아래에 넣어 칸 높이를 늘리지 않는다.
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("What's on your mind?")
                        .font(DS.notchBody)
                        .foregroundColor(palette.secondary)
                        // TextEditor 본문 인셋(가로 5pt)에 맞춘다.
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                TextEditor(text: $text)
                    .font(DS.notchBody)
                    .foregroundColor(palette.primary)
                    .scrollContentBackground(.hidden)
                    // 스크롤 막대 트랙이 상자 안에 상시 보이지 않게 한다 (트랙패드 스크롤은 유지).
                    .scrollIndicators(.never)
                    .focused($isFocused)
                    .disabled(!didLoad)
                    .accessibilityLabel("Quick Note")
            }
            .padding(EdgeInsets(top: 5, leading: 3, bottom: 16, trailing: 3))
            .frame(height: bodyHeight)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { editorFrame = geo.frame(in: .global) }
                        .onChange(of: geo.frame(in: .global)) { _, frame in editorFrame = frame }
                }
            )
            .overlay(alignment: .bottomTrailing) {
                // 오른쪽 아래 작은 저장 표시: 쓰는 동안 "Editing", 저장되면 "Saved · 시각/날짜".
                if let label = hasPendingEdit
                    ? "Editing" : QuickNoteStore.savedLabel(for: lastSaved)
                {
                    Text(label)
                        .font(DS.notchMeta)
                        .foregroundColor(palette.secondary)
                        .monospacedDigit()
                        .padding(EdgeInsets(top: 0, leading: 6, bottom: 4, trailing: 7))
                        .accessibilityLabel(label)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: DS.radiusSmall, style: .continuous)
                    .strokeBorder(
                        isFocused ? DS.accent.opacity(0.7) : palette.subtleSurface,
                        lineWidth: 1)
            )
            .padding(.horizontal, 4)
        }
        // 메모 상자 밖 빈 곳(도구 줄 여백·창 여백)을 누르면 커서를 푼다. 상자와 버튼은 자기 클릭을 먼저 받는다.
        .background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { isFocused = false }
        )
        .onAppear {
            load()
            if focusesOnAppear {
                // 패널이 key가 된 다음 틱에 커서를 넣는다.
                DispatchQueue.main.async { isFocused = true }
            }
        }
        .onChange(of: text) { _, newValue in
            guard didLoad else { return }
            let clamped = QuickNoteStore.clamped(newValue)
            if clamped != newValue {
                text = clamped
                return
            }
            hasPendingEdit = true
            debouncer.schedule { save(clamped) }
        }
        // 커서가 풀리면(다른 곳 클릭, 다른 앱, Esc) 기다리지 않고 바로 저장한다.
        .onChange(of: isFocused) { _, focused in
            if !focused { debouncer.flush() }
        }
        // 노치 패널 안에서 메모 상자 밖을 누르면 커서를 푼다. 패널이 key를 잃으면(다른 앱·바탕) 점 없이 온다.
        .onReceive(
            NotificationCenter.default.publisher(for: NotchLauncherController.didClickPanel)
        ) { note in
            guard isFocused else { return }
            if let point = note.userInfo?["point"] as? CGPoint, editorFrame.contains(point) {
                return
            }
            isFocused = false
        }
        // 분리 창: 다른 창·앱으로 가면 커서를 푼다.
        .onReceive(
            NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)
        ) { note in
            guard isFocused, let window = note.object as? NSWindow,
                window is QuickNoteWindowPanelMarker
            else { return }
            isFocused = false
        }
        .onDisappear { debouncer.flush() }
        // 창이 정리될 때는 onDisappear가 보장되지 않으므로 닫힘 직전에도 flush한다.
        .onReceive(
            NotificationCenter.default.publisher(for: NotchLauncherController.willHidePanel)
        ) { _ in
            debouncer.flush()
        }
        .onReceive(NotificationCenter.default.publisher(for: Self.flushRequest)) { _ in
            debouncer.flush()
        }
    }

    private func toolbarRow(_ toolbar: NotchQuickNoteToolbar) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "note.text")
                .font(DS.notchLabel)
                .foregroundColor(palette.heading)
            Text("Quick Note")
                .font(DS.notchLabel)
                .foregroundColor(palette.heading)
            Text(QuickNoteStore.characterCountLabel(text.count))
                .font(DS.notchMeta)
                .foregroundColor(palette.secondary)
                .monospacedDigit()
            Spacer(minLength: 0)
            toolButton(
                symbol: didCopy ? "checkmark" : "doc.on.doc",
                label: didCopy ? "Copied" : "Copy note", action: copyAll
            )
            .disabled(text.isEmpty)
            if let onDetach = toolbar.onDetach {
                toolButton(symbol: "macwindow.on.rectangle", label: "Open in a window") {
                    // 분리 창이 최신 내용을 읽도록 먼저 저장한다 (같은 직렬 큐라 순서가 보장된다).
                    debouncer.flush()
                    onDetach()
                }
            }
            if let onClose = toolbar.onClose {
                toolButton(symbol: "xmark", label: "Back to widgets", action: onClose)
            }
        }
        .padding(.horizontal, 6)
        .frame(height: DS.notchHeaderHeight)
    }

    private func toolButton(symbol: String, label: String, action: @escaping () -> Void)
        -> some View
    {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(palette.heading)
                .frame(width: 22, height: DS.notchHeaderHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }

    private func copyAll() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        didCopy = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { didCopy = false }
    }

    private func load() {
        guard !didLoad else { return }
        let store = store
        // 저장과 같은 직렬 큐에서 읽어, 방금 flush한 내용(분리 직전 입력)을 놓치지 않는다.
        Self.saveQueue.async {
            let saved = store.load()
            let date = saved.isEmpty ? nil : store.lastSavedDate()
            DispatchQueue.main.async {
                text = saved
                lastSaved = date
                didLoad = true
            }
        }
    }

    private func save(_ value: String) {
        let store = store
        Self.saveQueue.async {
            do {
                try store.save(value)
                let date = value.isEmpty ? nil : Date()
                DispatchQueue.main.async {
                    lastSaved = date
                    hasPendingEdit = false
                }
            } catch {
                Log.app.error(
                    "Quick Note save failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

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

    /// 윤곽선은 검정 띠에서도 몸통 가장자리가 보이도록 아주 짙은 남색이다.
    private static func color(_ ink: ChapMascot.Ink) -> Color {
        switch ink {
        case .outline: return Color(red: 22 / 255, green: 26 / 255, blue: 48 / 255)
        case .body: return .white
        case .shade: return Color(red: 176 / 255, green: 190 / 255, blue: 216 / 255)
        // 물: 검정 띠 위에서 물속은 깊은 블루, 마루와 물방울은 밝은 Chap 블루.
        case .water: return Color(red: 36 / 255, green: 64 / 255, blue: 170 / 255)
        case .crest: return Color(red: 110 / 255, green: 145 / 255, blue: 255 / 255)
        case .splash: return Color(red: 160 / 255, green: 185 / 255, blue: 255 / 255)
        }
    }

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
        .task(id: "\(moves)-\(mood)-\(wagsContinuously)") {
            pose = .rest
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
                let wait = Double.random(in: ChapMascot.idleFlickInterval)
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

/// 노치 선반(Screenshots·Downloads) 목록. 목록 칸 4줄 높이(113pt)에 고정하고, 더 있으면
/// 트랙패드·휠로 스크롤한다. 스크롤바는 시스템 설정("항상 보기")과 관계없이 숨기고,
/// 아래로 더 있을 때만 맨 아래를 살짝 흐리게 해 이어진다는 것을 알린다.
struct NotchShelfScrollList<Content: View>: View {
    let itemCount: Int
    let visibleRows: Int
    @ViewBuilder let content: () -> Content

    /// 맨 아래 흐림 높이. 끝까지 내리면 같은 만큼의 여백이 마지막 줄을 흐림 밖으로 올린다.
    private static var fadeHeight: CGFloat { 10 }

    private var scrolls: Bool { itemCount > visibleRows }

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: NotchAppIconTile.listRowSpacing) {
                content()
            }
            .padding(.bottom, scrolls ? Self.fadeHeight : 0)
        }
        .scrollIndicators(.never)
        .scrollDisabled(!scrolls)
        .frame(height: NotchAppIconTile.listBodyHeight, alignment: .top)
        .mask {
            VStack(spacing: 0) {
                Color.black
                LinearGradient(
                    colors: [.black, scrolls ? .black.opacity(0) : .black],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: Self.fadeHeight)
            }
        }
    }
}

/// 선반 제목에서 폴더 열기 요청. 앱이 일반 Finder 실행 경로(Standard 프리셋, 커서 화면
/// 가운데)로 연다. object는 폴더 URL, userInfo["name"]은 로그용 이름이다.
enum NotchShelfFolder {
    static let openRequest = Notification.Name("ChapShelfFolderOpen")

    static func open(_ url: URL, name: String) {
        NotificationCenter.default.post(name: openRequest, object: url, userInfo: ["name": name])
    }
}

/// 선반 제목 줄 오른쪽 끝의 접기 버튼. 칸에 마우스를 올렸을 때만 보인다.
/// 누르면 칸이 도커 어깨(검정 띠 옆 밝은 띠)의 아이콘으로 접힌다.
struct NotchCollapseButton: View {
    let isVisible: Bool
    let foreground: Color
    let hoverBackground: Color
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.up")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(foreground)
                .frame(width: 18, height: DS.notchHeaderHeight)
                .background(
                    RoundedRectangle(cornerRadius: DS.radiusSmall, style: .continuous)
                        .fill(isHovered ? hoverBackground : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .opacity(isVisible ? 1 : 0)
        .help("Collapse")
        .accessibilityLabel("Collapse")
    }
}

/// 검정 띠 왼쪽에 놓인 접힌 선반 아이콘. 띠 도구와 같은 흰색이며, 누르면 원래 자리에서 다시 펼쳐진다.
struct NotchStripShelfIcon: View {
    let symbol: String
    let title: String
    let height: CGFloat
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(DS.notchStripIconFont)
                .foregroundColor(DS.notchStripIconColor(isHovered: isHovered))
                .frame(width: NotchLauncherPolicy.stripToolPitch, height: height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("Show \(title)")
        .accessibilityLabel("Show \(title)")
    }
}

/// 분리된 Quick Note 창 표시. 창이 key를 잃을 때 메모 커서를 풀어 바로 저장하는 데 쓴다.
protocol QuickNoteWindowPanelMarker: AnyObject {}
