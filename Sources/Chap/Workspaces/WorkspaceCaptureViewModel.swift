import Combine
import Foundation

final class WorkspaceCaptureViewModel: ObservableObject {
    @Published var name = ""
    @Published private(set) var candidates: [WorkspaceWindow] = []
    @Published var selectedIDs: Set<UUID> = []
    @Published private(set) var isLoading = true
    /// 고를 수 있는 연결된 디스플레이. 하나뿐이면 고를 게 없어 메뉴를 숨긴다.
    @Published var displays: [WorkspaceDisplay] = []

    var offersDisplayChoice: Bool { displays.count > 1 }

    var selectedWindows: [WorkspaceWindow] {
        candidates.filter { selectedIDs.contains($0.id) }
    }

    var canSave: Bool {
        WorkspaceStore.cleanedName(name) != nil && !selectedWindows.isEmpty
    }

    /// 다시 읽기 시작. 이전 선택은 앱(번들 ID) 기준으로 기억해 새 후보에 다시 적용한다.
    func beginReloading() {
        isLoading = true
    }

    func finishLoading(_ windows: [WorkspaceWindow]) {
        let previouslySelected = Set(selectedWindows.map(\.bundleIdentifier))
        let previouslySeen = Set(candidates.map(\.bundleIdentifier))
        candidates = windows
        if previouslySeen.isEmpty {
            selectedIDs = Set(windows.prefix(WorkspaceStore.maxWindows).map(\.id))
        } else {
            // 다시 읽은 뒤: 전에 골랐던 앱은 그대로, 처음 보는 앱은 자리가 남으면 골라 둔다.
            var next = windows.filter { previouslySelected.contains($0.bundleIdentifier) }
            for window in windows where !previouslySeen.contains(window.bundleIdentifier) {
                guard next.count < WorkspaceStore.maxWindows else { break }
                next.append(window)
            }
            selectedIDs = Set(next.map(\.id))
        }
        isLoading = false
    }

    var isAtSelectionLimit: Bool { selectedIDs.count >= WorkspaceStore.maxWindows }

    /// 창 하나를 다른 디스플레이로 옮긴다(nil이면 Follow Cursor). 상대 위치·크기는 유지한다.
    func setDisplay(_ display: WorkspaceDisplay?, for id: UUID) {
        guard let index = candidates.firstIndex(where: { $0.id == id }) else { return }
        candidates[index] = candidates[index].assigned(to: display)
    }

    func toggle(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else if selectedIDs.count < WorkspaceStore.maxWindows {
            selectedIDs.insert(id)
        }
    }
}
