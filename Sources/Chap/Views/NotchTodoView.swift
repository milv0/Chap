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
    /// 파일에서 처음 읽었을 때 항목 문구를 알린다(도커가 칸 폭을 한 번 맞춘다).
    var onLoaded: ([String]) -> Void = { _ in }

    /// 마지막으로 알고 있는 항목 문구(메인 스레드 전용, 메모리에만). 도커를 열 때 칸 폭을 이것으로 정한다.
    /// 아직 한 번도 읽지 않았으면 nil이다.
    /// 렌더 도구가 `previewItems`를 쓰면 그 문구가 우선한다.
    static var knownTitles: [String]? {
        get { previewItems?.map(\.title) ?? cachedTitles }
        set { cachedTitles = newValue }
    }
    private static var cachedTitles: [String]?

    /// To-do 칸 폭: 가장 긴 항목 줄, 추가 줄, 제목 줄(남은 수 + 호버 시 Clear) 중 넓은 쪽을 140–240pt로.
    static func columnWidth(titles: [String]) -> CGFloat {
        // 항목 줄: 여백 5 + 동그라미 16 + 간격 6 + 문구 + 간격 6 + 삭제 16 + 여백 5.
        let longest = titles.map { 54 + NotchTextMetrics.bodyWidth($0) }.max() ?? 0
        // 추가 줄: 여백 5 + 더하기 16 + 간격 6 + 문구 + 여백 5.
        let addRow = 32 + NotchTextMetrics.bodyWidth("Add a to-do")
        // 제목 줄: 제목 + 간격 5 + "Clear" + 8 + "4 left" + 오른쪽 여백 6.
        let header =
            NotchTextMetrics.headerWidth(title: "To-do") + 5 + NotchTextMetrics.metaWidth("Clear")
            + 8 + NotchTextMetrics.metaWidth("\(TodoStore.maxItems) left") + 6
        return CGFloat(
            TodoColumnPolicy.columnWidth(contentWidth: Double(max(longest, addRow, header))))
    }

    /// 앱이 켜질 때 항목을 미리 읽어 둔다. 처음 여는 도커도 맞는 폭으로 열린다.
    static func preloadTitles() {
        guard knownTitles == nil else { return }
        let store = TodoStore()
        saveQueue.async {
            let titles = TodoStore.ordered(store.load()).map(\.title)
            DispatchQueue.main.async {
                if knownTitles == nil { knownTitles = titles }
            }
        }
    }

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
    /// 추가 줄 위에 마우스가 있는지. 있으면 글자만 액센트로 바뀐다.
    @State private var isAddHovered = false
    /// 칸 위에 마우스가 있는지. 있을 때만 제목 옆에 Clear가 나온다(평소엔 남은 수만).
    @State private var isColumnHovered = false
    /// 방금 비운 항목. 몇 초 동안 "Undo"로 되돌릴 수 있다.
    @State private var lastCleared: [TodoItem] = []
    /// "All done." 화면 대신 목록을 다시 보여 달라고 했는지(완료를 되돌리고 싶을 때).
    @State private var showsDoneList = false
    /// 되돌리기 줄이 사라질 때까지의 시간(초).
    private static let undoWindow: Double = 4
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

    private var completedCount: Int { items.lazy.filter(\.isDone).count }

    private var remainingCount: Int { items.count - completedCount }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            header
            // 항목과 추가 줄을 합쳐도 4줄을 넘지 않아 스크롤 없이 다른 목록 칸과 높이가 같다.
            Group {
                if TodoStore.isAllDone(items) && !showsDoneList {
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
        .onHover { inside in
            withAnimation(.easeOut(duration: 0.12)) { isColumnHovered = inside }
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

    /// 제목 줄은 다른 칸처럼 아이콘 + 제목 하나와, 오른쪽에 조용한 남은 수만 둔다.
    /// 진행선·캡슐 같은 장식은 두지 않는다(남은 수가 진행을 말한다).
    private var header: some View {
        HStack(spacing: 5) {
            NotchWidgetHeader(symbol: "checklist", title: "To-do", palette: palette)
            Spacer(minLength: 0)
            headerStatus
        }
        .frame(height: DS.notchHeaderHeight + 5, alignment: .top)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Clear Completed", action: clearCompleted)
                .disabled(completedCount == 0)
        }
    }

    @ViewBuilder
    private var headerStatus: some View {
        if !lastCleared.isEmpty {
            Button("Undo", action: undoClear)
                .buttonStyle(.plain)
                .font(DS.notchMeta.weight(.semibold))
                .foregroundColor(DS.accent)
                .frame(height: 16)
                .padding(.trailing, 6)
                .help("Bring the cleared to-dos back")
                .transition(.opacity)
                .task(id: lastCleared.map(\.id)) {
                    try? await Task.sleep(for: .seconds(Self.undoWindow))
                    guard !Task.isCancelled else { return }
                    withAnimation(.smooth(duration: 0.2)) { lastCleared = [] }
                }
        } else if !items.isEmpty {
            HStack(spacing: 8) {
                if completedCount > 0 && isColumnHovered
                    && !(TodoStore.isAllDone(items) && !showsDoneList)
                {
                    Button("Clear", action: clearCompleted)
                        .buttonStyle(.plain)
                        .font(DS.notchMeta.weight(.semibold))
                        .foregroundColor(DS.accent)
                        .accessibilityLabel("Clear \(completedCount) finished to-dos")
                        .help("Clear finished to-dos. You can undo right after.")
                        .transition(.opacity)
                }
                Text(remainingCount == 0 ? "Done" : "\(remainingCount) left")
                    .font(DS.notchMeta)
                    .foregroundColor(palette.secondary)
                    .monospacedDigit()
            }
            .frame(height: 16)
            .padding(.trailing, 6)
            .transition(.opacity)
        }
    }

    // MARK: - Rows

    private func row(_ item: TodoItem) -> some View {
        HStack(spacing: 6) {
            Button {
                toggle(item)
            } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15, weight: item.isDone ? .semibold : .regular))
                    // 완료는 색으로 외치지 않는다. 채운 체크 + 흐린 글자 + 취소선이면 충분하다.
                    .foregroundColor(palette.secondary.opacity(item.isDone ? 0.7 : 1))
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
                    .foregroundColor(
                        item.isDone ? palette.secondary.opacity(0.72) : palette.primary
                    )
                    .strikethrough(item.isDone, color: palette.secondary.opacity(0.8))
                    .lineLimit(1)
                    .truncationMode(.tail)
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
        .padding(.horizontal, 5)
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

    /// 추가 줄. 빈 자리도 무엇을 할 수 있는지 바로 알 수 있게 항상 문구를 보여 주고,
    /// 마우스를 올리거나 입력 중일 때만 액센트 면과 테두리로 반응한다.
    private var addRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "plus")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(isAddHovered || isAdding ? DS.accent : palette.secondary)
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
                Text("Add to-do")
                    .font(DS.notchRowName)
                    .foregroundColor(isAddHovered ? DS.accent : palette.secondary.opacity(0.7))
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 5)
        .frame(height: NotchAppIconTile.listRowHeight)
        // 면·테두리 없이 글자만. 다른 줄과 같은 26pt 자리라 목록이 한 표처럼 읽힌다.
        .background(
            RoundedRectangle(cornerRadius: DS.radiusSmall, style: .continuous)
                .fill(isAddHovered && !isAdding ? palette.hoverBackground : Color.clear)
        )
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
                // 다 끝내고 비우는 건 마무리라 되돌리기를 남기지 않는다. 다시 보고 싶으면 Back.
                capsuleButton("Clear", tint: DS.accent, fill: DS.accent.opacity(0.12)) {
                    clearCompleted(undoable: false)
                }
                .help("Clear finished to-dos")
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("All done")
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

    /// 완료 항목을 비운다. `undoable`이면 잠시 되돌릴 수 있게 기억한다(일부만 비울 때).
    private func clearCompleted() { clearCompleted(undoable: true) }

    private func clearCompleted(undoable: Bool) {
        let cleared = items.filter(\.isDone)
        guard !cleared.isEmpty else { return }
        withAnimation(.smooth(duration: 0.2)) {
            lastCleared = undoable ? cleared : []
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
                Self.knownTitles = loaded.map(\.title)
                onLoaded(loaded.map(\.title))
            }
        }
    }

    private func update(_ next: [TodoItem]) {
        items = next
        // 폭은 다음에 열 때 반영한다(열려 있는 동안은 그대로).
        Self.knownTitles = next.map(\.title)
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
