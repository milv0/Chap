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
                .foregroundColor(palette.heading)
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
                .foregroundColor(isOpen ? DS.accent : .white.opacity(isHovered ? 1 : 0.85))
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
    let showsMirror: Bool
    let showsNote: Bool

    private enum Tool: Equatable { case mirror, note }
    @State private var openTool: Tool?

    var body: some View {
        let tools: [Tool] = (showsMirror ? [.mirror] : []) + (showsNote ? [.note] : [])
        let offsets = NotchLauncherPolicy.stripToolCenterOffsets(
            besideDropBadge: besideDropBadge, count: tools.count)
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(Array(tools.enumerated()), id: \.offset) { index, tool in
                    let centerX = geo.size.width / 2 + notchRightEdge + offsets[index]
                    switch tool {
                    case .mirror:
                        NotchMirrorStripControl(
                            iconCenterX: centerX, stripHeight: stripHeight,
                            isOpen: binding(for: .mirror))
                    case .note:
                        NotchQuickNoteStripControl(
                            iconCenterX: centerX, stripHeight: stripHeight,
                            isOpen: binding(for: .note))
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
                let size =
                    open == .mirror
                    ? NotchMirrorStripControl.previewSize : NotchQuickNoteStripControl.popupSize
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

/// 상단 띠의 Quick Note 아이콘. 누르면 띠 바로 아래로 메모가 펼쳐져 전체 내용을 보고 쓸 수 있다.
struct NotchQuickNoteStripControl: View {
    let iconCenterX: CGFloat
    let stripHeight: CGFloat
    @Binding var isOpen: Bool

    @State private var isHovered = false

    static let popupSize = CGSize(width: 240, height: 128)

    /// 검정 띠에서 내려오는 어두운 카드에 맞춘 고정 색.
    private static let palette = NotchWidgetPalette(
        primary: .white.opacity(0.95), secondary: .white.opacity(0.6), accent: DS.accent,
        heading: .white.opacity(0.6), textShadowOpacity: 0,
        hoverBackground: .white.opacity(0.1), subtleSurface: .white.opacity(0.14))

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Button {
                    isOpen.toggle()
                } label: {
                    Image(systemName: "note.text")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isOpen ? DS.accent : .white.opacity(isHovered ? 1 : 0.85))
                        .frame(width: NotchLauncherPolicy.stripToolPitch, height: stripHeight)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { isHovered = $0 }
                .help(isOpen ? "Close Quick Note" : "Quick Note")
                .accessibilityLabel(isOpen ? "Close Quick Note" : "Quick Note")
                .position(x: iconCenterX, y: stripHeight / 2)

                if isOpen {
                    NotchQuickNoteView(
                        palette: Self.palette, showsHeader: false,
                        bodyHeight: Self.popupSize.height - 16, focusesOnAppear: true
                    )
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                    .frame(width: Self.popupSize.width, height: Self.popupSize.height)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(white: 0.1).opacity(0.96))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
                    .environment(\.colorScheme, .dark)
                    .position(
                        NotchLauncherPolicy.stripPopupCenter(
                            iconCenterX: iconCenterX, popupSize: Self.popupSize,
                            containerWidth: geo.size.width, stripHeight: stripHeight)
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .top)))
                }
            }
        }
        .animation(.smooth(duration: 0.18), value: isOpen)
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

/// 노치에서 바로 적는 한 장짜리 메모. 입력은 잠시 멈추면 저장되고,
/// 칸이 사라질 때 남은 변경을 즉시 저장한다.
struct NotchQuickNoteView: View {
    let palette: NotchWidgetPalette
    var showsHeader = true
    var bodyHeight: CGFloat = widgetBodyHeight
    /// 띠에서 펼칠 때는 바로 입력할 수 있게 커서를 넣는다.
    var focusesOnAppear = false

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
            if showsHeader {
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
    }

    private func load() {
        guard !didLoad else { return }
        let store = store
        DispatchQueue.global(qos: .userInitiated).async {
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
