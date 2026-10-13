import Combine
import Foundation

final class WorkspaceCaptureViewModel: ObservableObject {
    @Published var name = ""
    @Published private(set) var candidates: [WorkspaceWindow] = []
    @Published var selectedIDs: Set<UUID> = []
    @Published private(set) var isLoading = true

    var selectedWindows: [WorkspaceWindow] {
        candidates.filter { selectedIDs.contains($0.id) }
    }

    var canSave: Bool {
        WorkspaceStore.cleanedName(name) != nil && !selectedWindows.isEmpty
    }

    func finishLoading(_ windows: [WorkspaceWindow]) {
        candidates = windows
        selectedIDs = Set(windows.prefix(WorkspaceStore.maxWindows).map(\.id))
        isLoading = false
    }

    func toggle(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else if selectedIDs.count < WorkspaceStore.maxWindows {
            selectedIDs.insert(id)
        }
    }
}
