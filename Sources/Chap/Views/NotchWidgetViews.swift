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
                .font(DS.captionFont)
                .foregroundColor(palette.accent)
            Text(title)
                .font(DS.captionFont.weight(.semibold))
                .foregroundColor(palette.secondary)
        }
        .shadow(color: .black.opacity(palette.textShadowOpacity), radius: 1.5, y: 0.5)
        .padding(.horizontal, 6)
        .padding(.bottom, 1)
        .accessibilityAddTraits(.isHeader)
    }
}

/// 위젯 본문 높이. 런처 네 줄과 비슷해 도커 높이가 튀지 않는다.
private let widgetBodyHeight: CGFloat = 92

// MARK: - Mirror

/// 통화 전 얼굴을 비춰 보는 거울. 보이는 페이지의 열린 도커에서만 카메라를 켠다.
struct NotchMirrorView: View {
    /// 이 칸이 속한 페이지가 현재 보이는지.
    let isActive: Bool
    let palette: NotchWidgetPalette

    @State private var state = MirrorCamera.displayState

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
        .onChange(of: isActive) { _, _ in refresh() }
        .onDisappear { MirrorCamera.shared.stop() }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .live:
            MirrorPreview(session: MirrorCamera.shared.session)
                .accessibilityLabel("Camera mirror preview")
        case .needsPermission:
            message(
                "See yourself before a call.", button: "Turn On Mirror",
                action: requestAccess)
        case .denied:
            message(
                "Camera access is off for Chap.", button: "Open Settings",
                action: openCameraSettings)
        case .restricted:
            message("Camera access is restricted on this Mac.", button: nil, action: {})
        case .noCamera:
            message("No camera is connected.", button: nil, action: {})
        }
    }

    private func message(_ text: String, button: String?, action: @escaping () -> Void)
        -> some View
    {
        VStack(spacing: 6) {
            Image(systemName: "video.slash")
                .foregroundColor(palette.secondary)
            Text(text)
                .font(DS.captionFont)
                .foregroundColor(palette.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let button {
                Button(button, action: action)
                    .controlSize(.small)
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.subtleSurface)
    }

    private func refresh() {
        state = MirrorCamera.displayState
        if MirrorPolicy.shouldCapture(state: state, isPageActive: isActive, isPanelOpen: true) {
            MirrorCamera.shared.start()
        } else {
            MirrorCamera.shared.stop()
        }
    }

    private func requestAccess() {
        MirrorCamera.requestAccess { _ in refresh() }
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
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("Jot something down…")
                        .font(DS.captionFont)
                        .foregroundColor(palette.secondary.opacity(0.8))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                TextEditor(text: $text)
                    .font(DS.captionFont)
                    .foregroundColor(palette.primary)
                    .scrollContentBackground(.hidden)
                    .focused($isFocused)
                    .disabled(!didLoad)
                    .accessibilityLabel("Quick Note")
            }
            .padding(4)
            .frame(height: widgetBodyHeight)
            .background(
                RoundedRectangle(cornerRadius: DS.radiusSmall, style: .continuous)
                    .fill(palette.subtleSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.radiusSmall, style: .continuous)
                    .strokeBorder(DS.accent.opacity(isFocused ? 0.7 : 0), lineWidth: 1)
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
            DispatchQueue.main.async {
                text = saved
                didLoad = true
            }
        }
    }

    private func save(_ value: String) {
        let store = store
        Self.saveQueue.async {
            do {
                try store.save(value)
            } catch {
                Log.app.error(
                    "Quick Note save failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
