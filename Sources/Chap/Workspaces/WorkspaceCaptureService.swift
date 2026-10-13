import Cocoa
import os

/// 현재 실행 중인 앱의 대표 창을 Workspace 후보로 캡처한다.
enum WorkspaceCaptureService {
    private struct RunningApp: Sendable {
        let pid: pid_t
        let name: String
        let bundleIdentifier: String
        let path: String
        let isFrontmost: Bool
    }

    private struct DisplaySnapshot: Sendable {
        let identifier: String?
        let name: String
        let frame: CGRect
        let visibleFrame: CGRect
    }

    private static let queue = DispatchQueue(
        label: "com.mingyupark.Chap.workspace.capture", qos: .userInitiated)

    static func capture(
        frontmostBundleIdentifier: String?,
        completion: @escaping ([WorkspaceWindow]) -> Void
    ) {
        precondition(Thread.isMainThread)
        guard AccessibilityPermission.isTrusted else {
            completion([])
            return
        }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let apps = NSWorkspace.shared.runningApplications.compactMap { app -> RunningApp? in
            // 숨긴 앱(⌘H)의 창은 화면에 없으니 "지금 배열한 창"이 아니다.
            guard app.processIdentifier != ownPID, app.activationPolicy == .regular,
                !app.isTerminated, !app.isHidden, let bundleIdentifier = app.bundleIdentifier,
                let path = app.bundleURL?.path, let name = app.localizedName
            else { return nil }
            return RunningApp(
                pid: app.processIdentifier, name: name, bundleIdentifier: bundleIdentifier,
                path: path, isFrontmost: bundleIdentifier == frontmostBundleIdentifier)
        }
        .sorted {
            if $0.isFrontmost != $1.isFrontmost { return $0.isFrontmost }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        let screens = NSScreen.screens.map {
            DisplaySnapshot(
                identifier: displayUUID(for: $0), name: $0.localizedName,
                frame: $0.frame, visibleFrame: $0.visibleFrame)
        }
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0

        queue.async {
            let candidates = apps.compactMap { app in
                capture(app: app, screens: screens, primaryHeight: primaryHeight)
            }
            DispatchQueue.main.async { completion(candidates) }
        }
    }

    private static func capture(
        app: RunningApp, screens: [DisplaySnapshot], primaryHeight: CGFloat
    ) -> WorkspaceWindow? {
        guard let window = WorkspaceWindowAccess.representativeWindow(pid: app.pid),
            let position = LauncherUtils.axGetPosition(window),
            let size = LauncherUtils.axGetSize(window)
        else { return nil }
        let bounds = (
            left: Int(position.x.rounded()), top: Int(position.y.rounded()),
            right: Int((position.x + size.width).rounded()),
            bottom: Int((position.y + size.height).rounded())
        )
        let appKitFrame = appKitFrame(fromTopLeft: bounds, primaryHeight: primaryHeight)
        guard
            let screen = screens.max(by: {
                $0.frame.intersection(appKitFrame).area < $1.frame.intersection(appKitFrame).area
            }), screen.frame.intersects(appKitFrame)
        else { return nil }
        return WorkspaceWindow(
            applicationName: app.name, bundleIdentifier: app.bundleIdentifier,
            applicationPath: app.path, windowTitle: WorkspaceWindowAccess.windowTitle(window),
            displayIdentifier: screen.identifier, displayName: screen.name,
            frame: WorkspaceGeometry.capture(
                bounds: bounds, visibleFrame: screen.visibleFrame, primaryHeight: primaryHeight))
    }
}

extension CGRect {
    fileprivate var area: CGFloat { isNull ? 0 : width * height }
}
