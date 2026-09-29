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
    /// 패널 가운데에서 노치 오른쪽 끝까지의 거리 (노치 반폭).
    let notchRightEdge: CGFloat
    let stripHeight: CGFloat
    let besideDropBadge: Bool

    @State private var state = MirrorCamera.displayState
    @State private var isOpen = false
    @State private var isHovered = false

    /// 펼친 미리보기 크기 (16:9).
    static let previewSize = CGSize(width: 208, height: 117)
    /// 띠 아이콘의 누름 영역 폭. Drop 배지 본체 폭과 같다.
    static let iconWidth: CGFloat = NotchGeometry.badgeBodyWidth

    var body: some View {
        GeometryReader { geo in
            let iconCenterX =
                geo.size.width / 2 + notchRightEdge
                + (besideDropBadge
                    ? NotchGeometry.badgeBodyWidth + NotchGeometry.dockFlareRadius
                        + Self.iconWidth / 2
                    : Self.iconWidth / 2)
            ZStack(alignment: .topLeading) {
                stripButton
                    .position(x: iconCenterX, y: stripHeight / 2)
                if isOpen && state == .live {
                    preview
                        .position(
                            x: min(
                                max(iconCenterX, Self.previewSize.width / 2 + 12),
                                geo.size.width - Self.previewSize.width / 2 - 12),
                            y: stripHeight + 8 + Self.previewSize.height / 2
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .top)))
                }
            }
        }
        .animation(.smooth(duration: 0.18), value: isOpen)
        .onAppear { state = MirrorCamera.displayState }
        .onDisappear { turnOff() }
    }

    private var stripButton: some View {
        Button(action: tapped) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isOpen ? DS.accent : .white.opacity(isHovered ? 1 : 0.85))
                .frame(width: Self.iconWidth, height: stripHeight)
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
        MirrorPreview(session: MirrorCamera.shared.session)
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

    private func turnOn() {
        isOpen = true
        if MirrorPolicy.shouldCapture(state: state, isTurnedOn: true, isPanelOpen: true) {
            MirrorCamera.shared.start()
        }
    }

    private func turnOff() {
        isOpen = false
        MirrorCamera.shared.stop()
    }
}

/// 좌우 반전된 카메라 미리보기 레이어.
private struct MirrorPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        // 거울처럼 보이도록 좌우를 뒤집는다.
        if let connection = layer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
        view.layer = layer
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

// MARK: - Quick Note

/// 노치에서 바로 적는 한 장짜리 메모. 입력은 잠시 멈추면 저장되고,
/// 칸이 사라질 때 남은 변경을 즉시 저장한다.
struct NotchQuickNoteView: View {
    let palette: NotchWidgetPalette

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
            NotchWidgetHeader(symbol: "note.text", title: "Quick Note", palette: palette)
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
            .frame(height: widgetBodyHeight)
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
        .onAppear(perform: load)
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
