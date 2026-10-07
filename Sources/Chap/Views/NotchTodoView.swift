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

    @State private var items: [TodoItem] = NotchTodoView.previewItems ?? []
    @State private var didLoad = NotchTodoView.previewItems != nil
    @State private var draft = ""
    @State private var editingID: UUID?
    @State private var editDraft = ""
    @State private var isAdding = false
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
            VStack(alignment: .leading, spacing: NotchAppIconTile.listRowSpacing) {
                ForEach(items) { item in
                    row(item)
                }
                if TodoStore.canAdd(items) {
                    addRow
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
        .onChange(of: focus) { old, new in
            // 커서가 풀리면(Esc, 다른 앱, 다른 칸) 쓰던 내용을 확정한다.
            if old != nil, new == nil { finishEditing() }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 5) {
            NotchWidgetHeader(symbol: "checklist", title: "To-do", palette: palette)
            if let count = TodoStore.remainingLabel(items) {
                Text(count)
                    .font(DS.notchMeta)
                    .foregroundColor(palette.secondary)
                    .monospacedDigit()
                    .accessibilityLabel("\(count) left")
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button("Clear Completed") { update(TodoStore.clearingCompleted(items)) }
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
                    .strikethrough(item.isDone, color: palette.secondary)
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

    private var addRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "plus")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(palette.secondary)
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
                Text(items.isEmpty ? "Add a to-do" : "Add")
                    .font(DS.notchRowName)
                    .foregroundColor(palette.secondary)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .frame(height: NotchAppIconTile.listRowHeight)
        .contentShape(Rectangle())
        .onTapGesture { beginAdding() }
        .disabled(!didLoad)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Add a to-do")
        .accessibilityAddTraits(.isButton)
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
        withAnimation(.easeOut(duration: 0.15)) {
            update(TodoStore.toggling(item.id, in: items))
        }
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
