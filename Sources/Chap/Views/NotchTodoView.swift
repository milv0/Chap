import SwiftUI

/// 노치 할 일(To-do) 칸. 다른 목록 칸과 같은 26pt 줄에 체크 동그라미 + 12pt 문구, 맨 아래 "Add a to-do" 줄.
/// - 추가: 맨 아래 줄을 누르면 바로 입력, Enter로 더하고 다음 항목을 이어서 쓴다. 칸 밖을 누르거나
///   다른 앱으로 가면 입력이 끝나며 쓴 내용이 저장된다(Quick Note와 같은 규칙).
/// - 완료: 동그라미를 누르면 체크·취소선. 항목은 제자리에 있다(아래로 옮기지 않는다).
/// - 수정·삭제: 문구를 더블클릭해 고치고, 줄에 마우스를 올리면 오른쪽 끝에 나오는 ×나 우클릭으로 지운다.
///   제목 우클릭 → Clear Completed.
/// 최대 4개라 스크롤 없이 한눈에 보이고, 꽉 차면 추가 줄이 사라진다(완료 항목을 지우면 다시 생긴다).
/// 저장은 `TodoStore`(Chap 안에만, 권한 없음)이며 바뀔 때마다 직렬 큐로 바로 쓴다.
struct NotchTodoView: View {
    let palette: NotchWidgetPalette

    /// (렌더 도구) 설정하면 파일 대신 이 목록을 첫 프레임에 쓴다. 앱 실행 중에는 항상 nil이다.
    static var previewItems: [TodoItem]?

    /// 할 일을 하나 끝냈을 때 보낸다. 검정 띠의 물범이 꼬리를 한 번 까딱해 함께 기뻐한다.
    static let didCompleteNotification = Notification.Name("ChapTodoDidComplete")

    @State private var items: [TodoItem] = NotchTodoView.previewItems ?? []
    @State private var didLoad = NotchTodoView.previewItems != nil
    @State private var draft = ""
    @State private var editingID: UUID?
    @State private var editDraft = ""
    @State private var isAdding = false
    /// 추가 줄 위에 마우스가 있는지. 있을 때만 "Add a to-do" 글자가 보인다.
    @State private var isAddHovered = false
    /// 방금 비운 항목. 몇 초 동안 "Undo"로 되돌릴 수 있다.
    @State private var lastCleared: [TodoItem] = []
    /// "All done." 화면 대신 목록을 다시 보여 달라고 했는지(완료를 되돌리고 싶을 때).
    @State private var showsDoneList = false
    /// 되돌리기 줄이 사라질 때까지의 시간(초).
    private static let undoWindow: Double = 6
    /// 마우스가 올라간 줄. 그 줄 오른쪽 끝에 삭제 버튼이 보인다.
    @State private var hoveredID: UUID? = NotchTodoView.previewHoveredIndex.flatMap { index in
        NotchTodoView.previewItems.flatMap { $0.indices.contains(index) ? $0[index].id : nil }
    }
    /// (렌더 도구) 마우스를 올린 것처럼 보여 줄 줄 번호.
    static var previewHoveredIndex: Int?
    /// 입력 중인 줄의 화면 위치. 그 밖을 누르면 입력을 끝낸다.
    @State private var activeFieldFrame: CGRect = .zero
    @FocusState private var focus: Field?

    private enum Field: Hashable {
        case add
        case edit(UUID)
    }

    private let store = TodoStore()
    private static let saveQueue = DispatchQueue(
        label: "com.mingyupark.Chap.todo", qos: .utility)

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            header
            // 항목과 추가 줄을 합쳐도 4줄을 넘지 않아 스크롤 없이 다른 목록 칸과 높이가 같다.
            Group {
                if !lastCleared.isEmpty {
                    undoBanner
                } else if TodoStore.isAllDone(items) && !showsDoneList {
                    allDone
                } else {
                    VStack(alignment: .leading, spacing: NotchAppIconTile.listRowSpacing) {
                        ForEach(items) { item in
                            row(item)
                        }
                        if TodoStore.canAdd(items) {
                            addRow
                        }
                    }
                }
            }
            .frame(height: NotchAppIconTile.listBodyHeight, alignment: .top)
        }
        .onAppear(perform: load)
        // 칸 밖(노치 안 다른 곳)을 누르면 입력을 끝낸다. 패널이 key를 잃으면 점 없이 온다.
        .onReceive(
            NotificationCenter.default.publisher(for: NotchLauncherController.didClickPanel)
        ) { note in
            guard focus != nil else { return }
            if let point = note.userInfo?["point"] as? CGPoint, activeFieldFrame.contains(point) {
                return
            }
            finishEditing()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: NotchLauncherController.willHidePanel)
        ) { _ in
            finishEditing()
        }
        .onChange(of: TodoStore.isAllDone(items)) { _, allDone in
            if !allDone { showsDoneList = false }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: NotchLauncherController.willHidePanel)
        ) { _ in
            // 노치를 닫으면 되돌리기 기회도 끝난다.
            lastCleared = []
            showsDoneList = false
        }
        .onChange(of: focus) { old, new in
            // 커서가 풀리면(Esc, 다른 앱, 다른 칸) 쓰던 내용을 확정한다.
            if old != nil, new == nil { finishEditing() }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 5) {
            NotchWidgetHeader(symbol: "checklist", title: "To-do", palette: palette)
            // Things의 프로젝트 원처럼: 끝낸 비율만큼 차는 작은 원. 숫자보다 조용하게 진행을 보여 준다.
            if let progress = TodoStore.progress(items) {
                TodoProgressRing(progress: progress, palette: palette)
                    .help("\(items.filter(\.isDone).count) of \(items.count) done")
                    .accessibilityLabel("\(items.filter(\.isDone).count) of \(items.count) done")
            }
            Spacer(minLength: 0)
            // 끝낸 항목이 있으면 제목 줄 오른쪽에 작은 Clear. All done 화면에서 Back으로 돌아와도 바로 비울 수 있다.
            if items.contains(where: \.isDone), lastCleared.isEmpty,
                !(TodoStore.isAllDone(items) && !showsDoneList)
            {
                Button("Clear", action: clearCompleted)
                    .buttonStyle(.plain)
                    .font(DS.notchMeta.weight(.semibold))
                    .foregroundColor(DS.accent)
                    .padding(.trailing, 6)
                    .help("Clear finished to-dos. You can undo right after.")
                    .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button("Clear Completed", action: clearCompleted)
                .disabled(!items.contains(where: \.isDone))
        }
    }

    // MARK: - Rows

    private func row(_ item: TodoItem) -> some View {
        HStack(spacing: 6) {
            Button {
                toggle(item)
            } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundColor(item.isDone ? DS.accent : palette.secondary)
                    // 동그라미가 체크로 바뀌며 한 번 튄다(체크할 때만).
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: item.isDone)
                    .frame(width: DS.notchRowIconSize, height: DS.notchRowIconSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isDone ? "Mark not done" : "Mark done")

            if editingID == item.id {
                TextField("", text: $editDraft)
                    .textFieldStyle(.plain)
                    .font(DS.notchRowName)
                    .foregroundColor(palette.primary)
                    .focused($focus, equals: .edit(item.id))
                    .onSubmit { finishEditing() }
                    .background(fieldFrameReader)
            } else {
                Text(item.title)
                    .font(DS.notchRowName)
                    .foregroundColor(item.isDone ? palette.secondary : palette.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    // 취소선은 글자 위로 왼쪽에서 오른쪽으로 그어진다(글자 폭만큼).
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(palette.secondary)
                            .frame(height: 1)
                            .scaleEffect(x: item.isDone ? 1 : 0, anchor: .leading)
                            .animation(.easeOut(duration: 0.28), value: item.isDone)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { beginEditing(item) }
                    .help(item.title)
            }

            // 오른쪽 끝 삭제 버튼: 줄에 마우스를 올렸을 때만 보인다(자리는 늘 잡아 두어 글자가 밀리지 않는다).
            // Drop 파일 삭제와 같은 xmark를 조용한 회색으로, 버튼에 올리면 빨강으로 바뀐다.
            TodoDeleteButton(
                isVisible: hoveredID == item.id && editingID != item.id,
                palette: palette
            ) {
                withAnimation(.easeOut(duration: 0.15)) {
                    update(TodoStore.removing(item.id, from: items))
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .frame(height: NotchAppIconTile.listRowHeight)
        .background(
            RoundedRectangle(cornerRadius: DS.radiusSmall, style: .continuous)
                .fill(hoveredID == item.id ? palette.hoverBackground : Color.clear)
        )
        .onHover { inside in
            if inside {
                hoveredID = item.id
            } else if hoveredID == item.id {
                hoveredID = nil
            }
        }
        .contextMenu {
            Button(item.isDone ? "Mark Not Done" : "Mark Done") { toggle(item) }
            Button("Edit") { beginEditing(item) }
            Divider()
            Button("Delete", role: .destructive) {
                update(TodoStore.removing(item.id, from: items))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title)\(item.isDone ? ", done" : "")")
        .accessibilityAction(named: item.isDone ? "Mark Not Done" : "Mark Done") { toggle(item) }
        .accessibilityAction(named: "Delete") { update(TodoStore.removing(item.id, from: items)) }
    }

    /// 추가 줄. 목록을 방해하지 않도록 평소에는 체크 동그라미 자리에 옅은 ＋만 두고, 마우스를 올리거나
    /// 목록이 비어 있을 때만 "Add a to-do" 글자를 보여 준다.
    private var addRow: some View {
        let showsLabel = isAddHovered || items.isEmpty
        return HStack(spacing: 6) {
            Image(systemName: "plus")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(palette.secondary.opacity(isAddHovered || isAdding ? 1 : 0.55))
                .frame(width: DS.notchRowIconSize, height: DS.notchRowIconSize)
            if isAdding {
                TextField("Add a to-do", text: $draft)
                    .textFieldStyle(.plain)
                    .font(DS.notchRowName)
                    .foregroundColor(palette.primary)
                    .focused($focus, equals: .add)
                    .onSubmit(commitDraft)
                    .background(fieldFrameReader)
            } else {
                Text("Add a to-do")
                    .font(DS.notchRowName)
                    .foregroundColor(palette.secondary.opacity(0.8))
                    .opacity(showsLabel ? 1 : 0)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .frame(height: NotchAppIconTile.listRowHeight)
        .contentShape(Rectangle())
        .onHover { inside in
            withAnimation(.easeOut(duration: 0.12)) { isAddHovered = inside }
        }
        .onTapGesture { beginAdding() }
        .disabled(!didLoad)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Add a to-do")
        .accessibilityAddTraits(.isButton)
    }

    /// 다 끝냈을 때: 차분한 한 줄과 비우기. 축하는 이 정도로만 한다(관심을 조르지 않는다).
    private var allDone: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(DS.accent)
                .symbolEffect(.bounce, value: items.count)
            Text("All done.")
                .font(DS.notchLabel)
                .foregroundColor(palette.primary)
            HStack(spacing: 6) {
                // 목록을 다시 보여 준다: 체크를 풀어 되살리고 싶을 때.
                capsuleButton("Back", tint: palette.secondary, fill: palette.subtleSurface) {
                    withAnimation(.smooth(duration: 0.2)) { showsDoneList = true }
                }
                .help("Back to the list")
                capsuleButton("Clear", tint: DS.accent, fill: DS.accent.opacity(0.12)) {
                    clearCompleted()
                }
                .help("Clear finished to-dos. You can undo right after.")
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("All done")
    }

    /// 방금 비운 직후: "Cleared 3" + Undo. 몇 초 뒤 사라지고, 노치를 닫아도 사라진다.
    private var undoBanner: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)
            Text(lastCleared.count == 1 ? "Cleared 1 to-do" : "Cleared \(lastCleared.count) to-dos")
                .font(DS.notchMeta)
                .foregroundColor(palette.secondary)
            capsuleButton("Undo", tint: DS.accent, fill: DS.accent.opacity(0.12), action: undoClear)
                .help("Bring the cleared to-dos back")
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .task(id: lastCleared.map(\.id)) {
            try? await Task.sleep(for: .seconds(Self.undoWindow))
            guard !Task.isCancelled else { return }
            withAnimation(.smooth(duration: 0.2)) { lastCleared = [] }
        }
    }

    private func capsuleButton(
        _ title: String, tint: Color, fill: Color, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(DS.notchMeta.weight(.semibold))
                .foregroundColor(tint)
                .padding(.horizontal, 10)
                .frame(height: 18)
                .background(Capsule().fill(fill))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    /// 완료 항목을 비우고, 잠시 되돌릴 수 있게 기억한다.
    private func clearCompleted() {
        let cleared = items.filter(\.isDone)
        guard !cleared.isEmpty else { return }
        withAnimation(.smooth(duration: 0.2)) {
            lastCleared = cleared
            showsDoneList = false
            update(TodoStore.clearingCompleted(items))
        }
    }

    private func undoClear() {
        withAnimation(.smooth(duration: 0.2)) {
            update(TodoStore.restoring(lastCleared, into: items))
            lastCleared = []
        }
    }

    private var fieldFrameReader: some View {
        GeometryReader { geo in
            Color.clear
                .onAppear { activeFieldFrame = geo.frame(in: .global) }
                .onChange(of: geo.frame(in: .global)) { _, frame in activeFieldFrame = frame }
        }
    }

    // MARK: - Actions

    private func beginAdding() {
        guard didLoad, TodoStore.canAdd(items) else { return }
        isAdding = true
        // 패널이 key가 된 다음 틱에 커서를 넣는다.
        DispatchQueue.main.async { focus = .add }
    }

    /// Enter: 더하고 다음 항목을 이어서 쓸 수 있게 입력 줄을 열어 둔다(꽉 차면 닫는다).
    private func commitDraft() {
        let next = TodoStore.adding(draft, to: items)
        draft = ""
        if next != items { update(next) }
        if TodoStore.canAdd(next) {
            DispatchQueue.main.async { focus = .add }
        } else {
            isAdding = false
            focus = nil
        }
    }

    private func beginEditing(_ item: TodoItem) {
        finishEditing()
        editDraft = item.title
        editingID = item.id
        DispatchQueue.main.async { focus = .edit(item.id) }
    }

    /// 쓰던 내용을 확정하고 입력을 닫는다(빈 새 항목은 버리고, 비운 기존 항목은 지운다).
    private func finishEditing() {
        if isAdding {
            let next = TodoStore.adding(draft, to: items)
            draft = ""
            isAdding = false
            if next != items { update(next) }
        }
        if let id = editingID {
            editingID = nil
            let next = TodoStore.renaming(id, to: editDraft, in: items)
            if next != items { update(next) }
        }
        if focus != nil { focus = nil }
    }

    /// 완료를 켜고 끈다. 항목은 제자리에 있고 체크·취소선만 바뀐다.
    private func toggle(_ item: TodoItem) {
        let completing = !item.isDone
        withAnimation(.easeOut(duration: 0.15)) {
            update(TodoStore.toggling(item.id, in: items))
        }
        guard completing else { return }
        // 끝냈을 때만: 트랙패드가 "딱", 띠의 물범이 꼬리를 까딱.
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        NotificationCenter.default.post(name: Self.didCompleteNotification, object: nil)
    }

    // MARK: - Storage

    private func load() {
        guard !didLoad else { return }
        let store = store
        Self.saveQueue.async {
            let loaded = TodoStore.ordered(store.load())
            DispatchQueue.main.async {
                items = loaded
                didLoad = true
            }
        }
    }

    private func update(_ next: [TodoItem]) {
        items = next
        guard Self.previewItems == nil else { return }
        let store = store
        Self.saveQueue.async {
            do {
                try store.save(next)
            } catch {
                Log.app.error(
                    "To-do save failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

/// 할 일 줄 오른쪽 끝의 삭제 버튼. 보이지 않을 때도 자리를 차지해 문구가 흔들리지 않는다.
private struct TodoDeleteButton: View {
    let isVisible: Bool
    let palette: NotchWidgetPalette
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(isHovered ? .white : palette.secondary)
                .frame(width: 16, height: 16)
                .background(Circle().fill(isHovered ? DS.danger : Color.clear))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(isVisible)
        .help("Delete")
        // VoiceOver는 줄의 Delete 동작을 쓴다.
        .accessibilityHidden(true)
    }
}

/// 제목 옆 진행률 원. 끝낸 비율만큼 Chap 블루로 차고, 다 끝나면 가득 찬 원이 된다.
private struct TodoProgressRing: View {
    let progress: Double
    let palette: NotchWidgetPalette

    var body: some View {
        ZStack {
            Circle().stroke(palette.secondary.opacity(0.35), lineWidth: 1.5)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(DS.accent, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.3), value: progress)
            if progress >= 1 {
                Circle().fill(DS.accent).padding(2.5)
            }
        }
        .frame(width: 10, height: 10)
    }
}
