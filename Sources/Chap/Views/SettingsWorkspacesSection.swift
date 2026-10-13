import SwiftUI

/// 설정창 사이드바의 Workspaces 섹션. URL·App·Finder 섹션 아래에 같은 모양으로 붙는다.
/// 제목을 누르면 이 섹션이 "+"의 대상(새 캡처)이 되고, 줄을 누르면 오른쪽에 그 Workspace를 연다.
struct SettingsWorkspacesSection: View {
    let workspaces: [ChapWorkspace]
    let selectedID: UUID?
    let isFocused: Bool
    /// 검색어. 비어 있지 않으면 이름이 맞는 Workspace만 보이고, 하나도 없으면 섹션을 숨긴다.
    let searchText: String
    let onFocusSection: () -> Void
    let onSelect: (UUID) -> Void
    let onCapture: () -> Void

    private var visible: [ChapWorkspace] {
        searchText.isEmpty
            ? workspaces
            : workspaces.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        if !visible.isEmpty || searchText.isEmpty {
            header
            if visible.isEmpty {
                SidebarAddRow(label: "Capture Workspace", action: onCapture)
            }
            ForEach(visible) { workspace in
                SidebarItem(
                    icon: "rectangle.3.group",
                    name: workspace.name,
                    badge: "\(workspace.windows.count)",
                    isSelected: selectedID == workspace.id
                )
                .contentShape(Rectangle())
                .onTapGesture { onSelect(workspace.id) }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(workspace.name), \(workspace.windows.count) windows")
                .accessibilityAddTraits(
                    selectedID == workspace.id ? [.isButton, .isSelected] : .isButton)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 4) {
            Text("Workspaces")
                .fontWeight(isFocused ? .semibold : .regular)
                .foregroundColor(isFocused ? DS.accent : DS.textSecondary)
            Text("(\(workspaces.count)/\(WorkspaceStore.maxWorkspaces))")
                .foregroundColor(DS.textTertiary)
                .monospacedDigit()
            Spacer(minLength: 0)
        }
        .font(DS.captionFont)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(isFocused ? DS.accentSoft : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onFocusSection)
        .padding(.top, 5)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isFocused ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint("New items from + capture a workspace")
    }
}
