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
    /// 도커가 펼쳐져 있는 동안만 물범이 움직인다.
    var isAnimating = false

    /// 세션을 켜고 끄는 요청. 컨트롤러가 앱의 KeepAwakeController로 전달한다.
    static let activateRequest = Notification.Name("ChapFocusActivate")
    static let deactivateRequest = Notification.Name("ChapFocusDeactivate")

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            NotchWidgetHeader(symbol: "bolt.fill", title: "Focus", palette: palette)
            Group {
                if let sessionEnd, sessionEnd > Date() {
                    active(until: sessionEnd)
                } else {
                    idle
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: widgetBodyHeight)
        }
        .onReceive(
            NotificationCenter.default.publisher(for: KeepAwakeController.didChangeNotification)
        ) { note in
            sessionEnd = note.object as? Date
        }
    }

    /// 꺼짐: 잠든 물범 + 한 줄 + 시간 버튼 셋.
    private var idle: some View {
        VStack(spacing: 6) {
            NotchMascotView(
                pixelSize: ChapMascot.widgetPixelSize, mood: .asleep,
                isAnimating: isAnimating, zColor: palette.secondary)
            VStack(spacing: 1) {
                Text(KeepAwakePolicy.focusIdleLine)
                    .font(DS.notchLabel)
                    .foregroundColor(palette.primary)
                Text(KeepAwakePolicy.focusIdleHint)
                    .font(DS.notchMeta)
                    .foregroundColor(palette.secondary)
            }
            HStack(spacing: 5) {
                ForEach(KeepAwakePolicy.focusPresets, id: \.title) { preset in
                    FocusPresetButton(
                        title: KeepAwakePolicy.shortTitle(of: preset), palette: palette
                    ) {
                        NotificationCenter.default.post(
                            name: Self.activateRequest, object: preset.duration)
                    }
                    .help("Keep your Mac awake for \(preset.title.lowercased())")
                }
            }
        }
    }

    /// 켜짐: 깨어 있는 물범(30분 미만이면 졸림) + 남은 시간 + 위트 한 줄 + 끄기.
    private func active(until end: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = end.timeIntervalSince(context.date)
            VStack(spacing: 4) {
                NotchMascotView(
                    pixelSize: ChapMascot.widgetPixelSize,
                    mood: ChapMascot.focusMood(remaining: remaining),
                    isAnimating: isAnimating, wagsContinuously: true,
                    zColor: palette.secondary)
                Text(KeepAwakePolicy.remainingClockLabel(until: end, now: context.date))
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(palette.primary)
                Text(KeepAwakePolicy.focusActiveLine(remaining: remaining))
                    .font(DS.notchMeta)
                    .foregroundColor(palette.secondary)
                FocusPresetButton(
                    title: KeepAwakePolicy.focusOffTitle, palette: palette, isQuiet: true
                ) {
                    NotificationCenter.default.post(name: Self.deactivateRequest, object: nil)
                }
                .help("Turn off Keep Mac Awake")
                .padding(.top, 2)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "Focus on, \(KeepAwakePolicy.remainingLabel(until: end, now: context.date)) left")
        }
    }
}

/// Focus 위젯의 작은 캡슐 버튼.
private struct FocusPresetButton: View {
    let title: String
    let palette: NotchWidgetPalette
    var isQuiet = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DS.notchMeta.weight(.semibold))
                .foregroundColor(
                    isQuiet ? palette.secondary : (isHovered ? .white : palette.primary)
                )
                .padding(.horizontal, isQuiet ? 8 : 9)
                .padding(.vertical, 3)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            isQuiet
                                ? palette.subtleSurface
                                : (isHovered ? DS.accent : palette.subtleSurface))
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
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
                .font(.system(size: 13, weight: .medium))
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
                        .font(.system(size: 12))
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
                .font(.system(size: 13, weight: .medium))
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
            .overlay(alignment: .bottomTrailing) {
                if let label = QuickNoteStore.savedLabel(for: lastSaved) {
                    Text(label)
                        .font(DS.notchMeta)
                        .foregroundColor(palette.secondary)
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
            debouncer.schedule { save(clamped) }
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
                DispatchQueue.main.async { lastSaved = date }
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pose: ChapMascot.Pose = .rest
    @State private var isBlinking = false
    @State private var zRisen = false

    private var moves: Bool { isAnimating && !reduceMotion }

    private var eyes: ChapMascot.Eyes {
        isBlinking && mood != .asleep ? .closed : mood.eyes
    }

    /// 까딱 한 번을 재생한다. 취소되면 쉬는 자세로 돌아간다.
    private func flick() async {
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
        }
    }

    var body: some View {
        Canvas { context, _ in
            for pixel in ChapMascot.pixels(eyes: eyes, pose: pose) {
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
        // 꼬리: 깨어 있는 동안에만. 잠에서 깨면(mood 변경) 곧바로 한 번 까딱해 반긴다.
        // Focus 칸에서는 그 뒤 쉬지 않고 흔들며, 졸리면 느려진다.
        .task(id: "\(moves)-\(mood)-\(wagsContinuously)") {
            pose = .rest
            guard moves, mood != .asleep else { return }
            try? await Task.sleep(for: .seconds(ChapMascot.openFlickDelay))
            if wagsContinuously, let frame = ChapMascot.focusWagFrameDuration(for: mood) {
                await flick()
                while !Task.isCancelled {
                    pose = pose == .rest ? .tailUp : .rest
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
