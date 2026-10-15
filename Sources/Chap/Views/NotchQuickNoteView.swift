import SwiftUI

// MARK: - Quick Note

/// Quick Note 창(`QuickNoteWindow`)의 한 장짜리 메모. 입력은 잠시 멈추면 저장되고,
/// 커서가 풀리거나 창이 닫힐 때 남은 변경을 즉시 저장한다. 덮어쓰기 전 백업은 `QuickNoteStore`가 맡는다.
struct NotchQuickNoteView: View {
    /// 대기 중인 저장을 즉시 쓰라는 요청 (메모 창 닫힘, 앱 종료).
    static let flushRequest = Notification.Name("ChapQuickNoteFlush")

    /// 대기 중인 저장이 파일에 다 쓰일 때까지 기다린다 (앱 종료 직전).
    static func drainPendingSaves() {
        saveQueue.sync {}
    }

    let palette: NotchWidgetPalette
    var bodyHeight: CGFloat = widgetBodyHeight
    /// 창이 뜨면 바로 입력할 수 있게 커서를 넣는다.
    var focusesOnAppear = false
    /// 창 chrome에서는 시스템 traffic light가 차지하는 왼쪽 여백.
    var toolbarLeadingInset: CGFloat = 0
    /// 노치에서는 짧고, 분리 창에서는 titlebar 높이에 맞춘다.
    var toolbarHeight: CGFloat = DS.notchHeaderHeight
    /// 분리 창의 커스텀 chrome일 때 도구 줄 아래에 미세한 구분선을 둔다.
    var showsToolbarDivider = false
    /// 오프스크린 렌더에서만 쓰는 고정 메모. 실제 저장소를 읽거나 쓰지 않는다.
    var previewText: String? = nil

    @State private var didCopy = false

    @State private var text = ""
    @State private var didLoad = false
    @State private var lastSaved: Date?
    /// 입력 뒤 아직 파일에 쓰이지 않은 변경이 있는지. 있으면 저장 표시 대신 "Editing"을 보여 준다.
    @State private var hasPendingEdit = false
    /// 마지막 저장이 실패했는지. 실패하면 "Couldn't save"를 보여 준다(입력은 화면에 남아 있다).
    @State private var saveFailed = false
    /// 메모 파일을 읽지 못했을 때 빈 상자 대신 보여 줄 안내.
    @State private var loadNotice: String?
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
            toolbarRow
            // 목록 본문과 같은 13pt. 회색 상자 대신 옅은 테두리만 두고,
            // 저장 시각은 상자 안 오른쪽 아래에 넣어 칸 높이를 늘리지 않는다.
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(loadNotice ?? "What's on your mind?")
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
                if let label = saveFailed
                    ? "Couldn't save"
                    : hasPendingEdit ? "Editing" : QuickNoteStore.savedLabel(for: lastSaved)
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
            if let previewText {
                text = previewText
                didLoad = true
            } else {
                load()
            }
            if focusesOnAppear {
                // 패널이 key가 된 다음 틱에 커서를 넣는다.
                DispatchQueue.main.async { isFocused = true }
            }
        }
        .onChange(of: text) { _, newValue in
            // 렌더 프리뷰는 실제 메모를 바꾸지 않는다.
            guard didLoad, previewText == nil else { return }
            let clamped = QuickNoteStore.clamped(newValue)
            if clamped != newValue {
                text = clamped
                return
            }
            hasPendingEdit = true
            loadNotice = nil
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
        // 메모 창: 다른 창·앱으로 가면 커서를 푼다.
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

    private var toolbarRow: some View {
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
            toolButton(
                symbol: "clock.arrow.circlepath", label: "Show Backups", action: showBackups)
        }
        .padding(.leading, 6 + toolbarLeadingInset)
        .padding(.trailing, 6)
        .frame(height: toolbarHeight)
        .overlay(alignment: .bottom) {
            if showsToolbarDivider {
                Rectangle()
                    .fill(palette.subtleSurface)
                    .frame(height: 1)
            }
        }
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

    /// 이전 메모 백업 폴더를 Finder로 연다 (아직 없으면 만든다).
    private func showBackups() {
        let folder = store.backupDirectoryURL
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(folder)
    }

    private func load() {
        guard !didLoad else { return }
        let store = store
        // 저장과 같은 직렬 큐에서 읽어, 방금 flush한 내용(창을 닫기 직전 입력)을 놓치지 않는다.
        Self.saveQueue.async {
            let result = store.loadResult()
            let date = store.lastSavedDate()
            DispatchQueue.main.async {
                switch result {
                case .text(let saved):
                    text = saved
                    lastSaved = saved.isEmpty ? nil : date
                    didLoad = true
                case .preserved(let url):
                    // 원본은 백업 폴더로 옮겼으니 빈 메모로 새로 시작해도 잃는 것이 없다.
                    Log.app.error(
                        "Quick Note was unreadable; moved to \(url.path, privacy: .public)")
                    loadNotice = "Couldn't read your last note. It's kept in Backups."
                    didLoad = true
                case .locked:
                    // 원본을 읽지도 옮기지도 못했다. 덮어쓰지 않도록 편집을 막고, 다음에 열 때 다시 읽는다.
                    Log.app.error("Quick Note file could not be read; editing is off")
                    loadNotice = "Can't open the note file, so Chap won't change it."
                }
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
                    saveFailed = false
                }
            } catch {
                Log.app.error(
                    "Quick Note save failed: \(error.localizedDescription, privacy: .public)")
                DispatchQueue.main.async { saveFailed = true }
            }
        }
    }
}

/// 분리된 Quick Note 창 표시. 창이 key를 잃을 때 메모 커서를 풀어 바로 저장하는 데 쓴다.
protocol QuickNoteWindowPanelMarker: AnyObject {}
