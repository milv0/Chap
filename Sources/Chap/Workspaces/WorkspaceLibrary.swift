import AppKit
import Combine
import Foundation
import os

/// 저장된 Workspace의 단일 출처. 메뉴·노치·설정창(Launchers의 Workspaces 섹션)이 같은 목록을 보고,
/// 바뀌면 `onChange`로 AppDelegate가 메뉴와 노치를 다시 그린다. 모든 호출은 메인 스레드.
final class WorkspaceLibrary: ObservableObject {
    @Published private(set) var workspaces: [ChapWorkspace] = []
    /// 지금 열거나(복원) 위치를 갱신하는 중인 Workspace. 버튼과 노치 줄이 진행 표시로 바뀐다.
    @Published var busyID: UUID?
    let store: WorkspaceStore
    /// 저장에 성공해 목록이 바뀐 뒤 불린다.
    var onChange: () -> Void = {}

    init(store: WorkspaceStore = WorkspaceStore()) {
        self.store = store
    }

    var canAdd: Bool { workspaces.count < WorkspaceStore.maxWorkspaces }

    func workspace(id: UUID) -> ChapWorkspace? {
        workspaces.first { $0.id == id }
    }

    func load() {
        workspaces = store.load()
    }

    /// 새로 캡처한 Workspace를 더한다. 저장했으면 그 id.
    @discardableResult
    func add(name: String, windows: [WorkspaceWindow]) -> UUID? {
        let updated = WorkspaceStore.adding(name: name, windows: windows, to: workspaces)
        guard updated != workspaces, save(updated) else { return nil }
        return updated.last?.id
    }

    /// 이름·창·디스플레이를 고친다. 바뀐 게 없으면 저장하지 않고 성공으로 본다.
    @discardableResult
    func replace(_ id: UUID, name: String, windows: [WorkspaceWindow]) -> Bool {
        let updated = WorkspaceStore.replacing(id, name: name, windows: windows, in: workspaces)
        return updated == workspaces || save(updated)
    }

    @discardableResult
    func remove(_ id: UUID) -> Bool {
        save(WorkspaceStore.removing(id, from: workspaces))
    }

    @discardableResult
    private func save(_ updated: [ChapWorkspace]) -> Bool {
        do {
            try store.save(updated)
            workspaces = updated
            onChange()
            return true
        } catch {
            Log.app.error(
                "Workspace save failed: \(error.localizedDescription, privacy: .public)")
            WorkspaceAlert.show(
                message: "Workspace was not saved", info: error.localizedDescription)
            return false
        }
    }
}

/// Workspace 작업의 알림. 복원 직후에는 다른 앱이 앞에 있으므로 Chap을 앞으로 가져와 띄운다
/// (`LauncherUtils.showAlert`는 활성화하지 않아 알림이 다른 앱 뒤에 숨는다).
enum WorkspaceAlert {
    static func show(message: String, info: String? = nil) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = message
            if let info { alert.informativeText = info }
            alert.alertStyle = .warning
            NSApp.activate(ignoringOtherApps: true)
            alert.window.level = .floating
            alert.runModal()
        }
    }
}

extension WorkspaceDisplay {
    /// 지금 연결된 디스플레이. 메뉴·미리보기·캡처·복원이 모두 같은 목록을 쓴다.
    static func connected() -> [WorkspaceDisplay] {
        NSScreen.screens.map {
            WorkspaceDisplay(identifier: displayUUID(for: $0), name: $0.localizedName)
        }
    }
}
