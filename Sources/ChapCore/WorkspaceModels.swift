import Foundation

/// 한 디스플레이의 visibleFrame을 기준으로 정규화한 창 프레임.
/// 좌표는 AX와 같은 좌상단 원점이며, 각 값은 0...1 범위다.
public struct WorkspaceFrame: Codable, Equatable, Sendable {
    public var left: Double
    public var top: Double
    public var width: Double
    public var height: Double

    public init(left: Double, top: Double, width: Double, height: Double) {
        self.left = left
        self.top = top
        self.width = width
        self.height = height
    }
}

/// 다시 실행하고 배치할 수 있는 macOS 앱 창 하나.
/// v1은 앱당 대표 창 하나만 저장하며, 창 제목은 같은 앱의 여러 창을 추측 없이 구분할 때만 쓴다.
public struct WorkspaceWindow: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var applicationName: String
    public var bundleIdentifier: String
    public var applicationPath: String
    public var windowTitle: String?
    public var displayIdentifier: String?
    public var displayName: String?
    public var frame: WorkspaceFrame

    public init(
        id: UUID = UUID(), applicationName: String, bundleIdentifier: String,
        applicationPath: String, windowTitle: String? = nil,
        displayIdentifier: String? = nil, displayName: String? = nil,
        frame: WorkspaceFrame
    ) {
        self.id = id
        self.applicationName = applicationName
        self.bundleIdentifier = bundleIdentifier
        self.applicationPath = applicationPath
        self.windowTitle = windowTitle
        self.displayIdentifier = displayIdentifier
        self.displayName = displayName
        self.frame = frame
    }
}

/// 실제로 배열한 앱 창들과 그 위치를 함께 기억하는 로컬 작업 공간.
public struct ChapWorkspace: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var windows: [WorkspaceWindow]

    public init(id: UUID = UUID(), name: String, windows: [WorkspaceWindow]) {
        self.id = id
        self.name = name
        self.windows = windows
    }
}

/// 창을 띄울 디스플레이. Workspace에는 UUID와 이름으로 저장하고, nil이면 Follow Cursor
/// (열 때 커서가 있는 화면)다.
public struct WorkspaceDisplay: Equatable, Hashable, Sendable {
    public let identifier: String?
    public let name: String

    public init(identifier: String?, name: String) {
        self.identifier = identifier
        self.name = name
    }

    /// 메뉴에 보일 이름. 같은 모델 모니터가 여럿이면 연결 순서대로 번호를 붙여 구분한다.
    public static func menuLabels(for displays: [WorkspaceDisplay]) -> [String] {
        var seen: [String: Int] = [:]
        let counts = Dictionary(grouping: displays, by: \.name).mapValues(\.count)
        return displays.map { display in
            guard (counts[display.name] ?? 0) > 1 else { return display.name }
            let index = (seen[display.name] ?? 0) + 1
            seen[display.name] = index
            return "\(display.name) \(index)"
        }
    }
}

extension WorkspaceWindow {
    /// 저장된 디스플레이. 둘 다 비어 있으면 Follow Cursor라 nil이다.
    public var display: WorkspaceDisplay? {
        guard displayIdentifier != nil || displayName != nil else { return nil }
        return WorkspaceDisplay(identifier: displayIdentifier, name: displayName ?? "")
    }

    /// 다른 디스플레이로 옮긴 사본. 창의 상대 위치·크기는 그대로 둔다(새 화면에서도 같은 비율).
    /// nil이면 Follow Cursor.
    public func assigned(to display: WorkspaceDisplay?) -> WorkspaceWindow {
        var copy = self
        copy.displayIdentifier = display?.identifier
        copy.displayName = display?.name
        return copy
    }
}
