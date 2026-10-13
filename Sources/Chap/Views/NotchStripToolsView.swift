import AVFoundation
import SwiftUI

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
    /// Cover Screens 아이콘. Quick Note 오른쪽(띠 도구의 끝)에 둔다.
    var showsCoverScreens = false

    private enum Tool: Equatable { case mirror, note, coverScreens }
    @State private var openTool: Tool?

    var body: some View {
        let tools: [Tool] =
            (showsMirror ? [.mirror] : []) + (showsNote ? [.note] : [])
            + (showsCoverScreens ? [.coverScreens] : [])
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
                            iconCenterX: centerX, stripHeight: stripHeight)
                    case .coverScreens:
                        NotchCoverScreensStripButton(
                            iconCenterX: centerX, stripHeight: stripHeight)
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
                // 팝업으로 뜨는 도구는 Mirror뿐이다 (Quick Note는 노치 아래 창으로 연다).
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

/// 상단 띠의 Quick Note 아이콘. 누르면 도커를 접고 노치 바로 아래에 Quick Note 창을 띄운다.
/// 창이 이미 열려 있으면 그 창을 앞으로 가져온다.
struct NotchQuickNoteStripButton: View {
    let iconCenterX: CGFloat
    let stripHeight: CGFloat

    @State private var isHovered = false

    var body: some View {
        Button {
            // 도커가 창 자리(노치 아래)를 덮지 않도록 먼저 접는다.
            NotificationCenter.default.post(
                name: NotchLauncherController.requestClose, object: nil)
            QuickNoteWindow.show()
        } label: {
            Image(systemName: "note.text")
                .font(DS.notchStripIconFont)
                .foregroundColor(DS.notchStripIconColor(isHovered: isHovered))
                .frame(width: NotchLauncherPolicy.stripToolPitch, height: stripHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("Quick Note")
        .accessibilityLabel("Quick Note")
        .position(x: iconCenterX, y: stripHeight / 2)
    }
}

/// 상단 띠의 Cover Screens 아이콘. 누르면 도커를 접고 모든 화면을 가림막으로 덮는다.
/// 덮인 뒤에는 노치가 가려지므로 여기서 끌 수 없다. 돌아올 때는 ⌥만 한 번 누른다.
struct NotchCoverScreensStripButton: View {
    /// 눌렀을 때 AppDelegate가 가림막을 친다 (메뉴바의 Cover Screens와 같은 동작).
    static let request = Notification.Name("ChapCoverScreensRequest")

    let iconCenterX: CGFloat
    let stripHeight: CGFloat

    @State private var isHovered = false

    var body: some View {
        Button {
            NotificationCenter.default.post(name: Self.request, object: nil)
        } label: {
            Image(systemName: "moon.fill")
                .font(DS.notchStripIconFont)
                .foregroundColor(DS.notchStripIconColor(isHovered: isHovered))
                .frame(width: NotchLauncherPolicy.stripToolPitch, height: stripHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("Cover Screens. Tap ⌥ Option to come back.")
        .accessibilityLabel(CoverScreensPolicy.menuTitleOff)
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
