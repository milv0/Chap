import AVFoundation
import SwiftUI

/// 노치 위젯이 공유하는 전경 색 묶음. 패널 스타일(Custom/Glass)에 맞춰 계산된 값을 받는다.
struct NotchWidgetPalette {
    let primary: Color
    let secondary: Color
    let accent: Color
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
                .foregroundColor(palette.secondary)
            Text(title)
                .font(DS.notchLabel)
                .foregroundColor(palette.secondary)
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

/// 통화 전 얼굴을 비춰 보는 거울. 사용자가 켠 뒤 도커가 열려 있는 동안만 카메라를 쓴다.
struct NotchMirrorView: View {
    let palette: NotchWidgetPalette

    @State private var state = MirrorCamera.displayState
    /// 도커를 열 때마다 꺼진 상태로 시작한다. 켜기 전에는 카메라를 쓰지 않는다.
    @State private var isTurnedOn = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            NotchWidgetHeader(symbol: "person.crop.square", title: "Mirror", palette: palette)
            content
                .frame(maxWidth: .infinity)
                .frame(height: widgetBodyHeight)
                .clipShape(RoundedRectangle(cornerRadius: DS.radiusSmall, style: .continuous))
                .padding(.horizontal, 4)
        }
        .onAppear { refresh() }
        .onDisappear { MirrorCamera.shared.stop() }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .live where isTurnedOn:
            MirrorPreview(session: MirrorCamera.shared.session)
                .accessibilityLabel("Camera mirror preview")
                .overlay(alignment: .topTrailing) {
                    Button {
                        isTurnedOn = false
                        refresh()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 16, height: 16)
                            .background(Circle().fill(.black.opacity(0.45)))
                    }
                    .buttonStyle(.plain)
                    .padding(4)
                    .accessibilityLabel("Turn off Mirror")
                }
        case .live:
            resting(symbol: "web.camera", caption: "Turn On Mirror", action: turnOn)
        case .needsPermission:
            // 처음 누를 때만 권한을 묻고, 허용하면 바로 켠다.
            resting(symbol: "web.camera", caption: "Turn On Mirror", action: requestAccess)
        case .denied:
            resting(
                symbol: "video.slash", caption: "Camera Off · Open Settings",
                action: openCameraSettings)
        case .restricted:
            resting(symbol: "video.slash", caption: "Camera Restricted", action: nil)
        case .noCamera:
            resting(symbol: "video.slash", caption: "No Camera", action: nil)
        }
    }

    /// 꺼진 거울: 상자 없이 큰 아이콘과 짧은 안내만 둔다. 누를 수 있으면 호버 면이 생긴다.
    private func resting(symbol: String, caption: String, action: (() -> Void)?) -> some View {
        Button {
            action?()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 30, weight: .light))
                    .foregroundColor(palette.primary.opacity(action == nil ? 0.5 : 0.9))
                Text(caption)
                    .font(DS.notchLabel)
                    .foregroundColor(palette.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: DS.radiusSmall, style: .continuous)
                    .fill(isRestingHovered && action != nil ? palette.hoverBackground : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .onHover { isRestingHovered = $0 }
        .accessibilityLabel(caption)
    }

    @State private var isRestingHovered = false

    private func turnOn() {
        isTurnedOn = true
        refresh()
    }

    private func refresh() {
        state = MirrorCamera.displayState
        if MirrorPolicy.shouldCapture(
            state: state, isTurnedOn: isTurnedOn, isPanelOpen: true)
        {
            MirrorCamera.shared.start()
        } else {
            MirrorCamera.shared.stop()
        }
    }

    private func requestAccess() {
        // 권한을 허용하면 누른 김에 바로 거울을 켠다.
        MirrorCamera.requestAccess { granted in
            isTurnedOn = granted
            refresh()
        }
    }

    private func openCameraSettings() {
        if let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")
        {
            NSWorkspace.shared.open(url)
        }
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
