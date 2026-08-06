import Foundation

public enum Defaults {
    /// 앱 번들의 CFBundleShortVersionString에서 읽음 (About 창 표시용).
    /// Info.plist / MARKETING_VERSION과 단일 소스로 유지된다.
    public static let appVersion: String =
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
        ?? "1.0.0"
    public static let configPath = NSString(string: "~/.chap.json").expandingTildeInPath
    /// 새로 추가한 사이트의 기본 이름 겸 "아직 미완성" 판별용 센티넬.
    /// placeholder 폐기·필수필드 검증·자동 네이밍 로직이 이 값을 기준으로 동작한다.
    public static let newSiteName = "New Launchable"
    public static let defaultWidth = 800
    public static let defaultHeight = 600
    public static let defaultWindowAspectRatio = 16.0 / 10.0

    public static let domainRegex = try? NSRegularExpression(pattern: "^[a-zA-Z0-9._-]+$")
}

public enum LaunchType: String, Codable, CaseIterable {
    case url
    case app
    case finder
    case shell
}

public struct WindowSizePreset: Equatable, Identifiable {
    public let id: String
    public let label: String
    public let widthRatio: Double
    public let heightRatio: Double
    public let aspectRatio: Double?

    public var ratioText: String {
        if aspectRatio != nil {
            return "16:10"
        }
        let widthPercent = Int((widthRatio * 100).rounded())
        let heightPercent = Int((heightRatio * 100).rounded())
        if widthPercent == heightPercent {
            return "\(widthPercent)%"
        }
        return "\(widthPercent)x\(heightPercent)%"
    }
}

public enum WindowSizePresets {
    public static let compact = WindowSizePreset(
        id: "compact", label: "Compact", widthRatio: 0.42, heightRatio: 0.46, aspectRatio: nil)
    public static let focus = WindowSizePreset(
        id: "focus", label: "Focus", widthRatio: 0.55, heightRatio: 0.58, aspectRatio: nil)
    public static let standard = WindowSizePreset(
        id: "standard", label: "Standard", widthRatio: 0.66, heightRatio: 0.66,
        aspectRatio: Defaults.defaultWindowAspectRatio)
    public static let comfortable = WindowSizePreset(
        id: "comfortable", label: "Comfortable", widthRatio: 0.74, heightRatio: 0.76,
        aspectRatio: nil)
    public static let wide = WindowSizePreset(
        id: "wide", label: "Wide", widthRatio: 0.69, heightRatio: 0.59, aspectRatio: nil)
    public static let tall = WindowSizePreset(
        id: "tall", label: "Tall", widthRatio: 0.38, heightRatio: 0.80, aspectRatio: nil)
    public static let workspace = WindowSizePreset(
        id: "workspace", label: "Workspace", widthRatio: 0.86, heightRatio: 0.86,
        aspectRatio: nil)
    public static let max = WindowSizePreset(
        id: "max", label: "Max", widthRatio: 0.94, heightRatio: 0.92, aspectRatio: nil)

    public static let all = [compact, focus, standard, comfortable, wide, tall, workspace, max]

    public static func preset(withID id: String?) -> WindowSizePreset? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }
}

public struct InitialWindowSizeRecommendation: Equatable {
    public let widthRatio: Double
    public let heightRatio: Double
    public let aspectRatio: Double?
    public let sizePresetID: String?
}

public enum InitialWindowSizeRecommendations {
    public static func recommendation(for type: LaunchType) -> InitialWindowSizeRecommendation {
        switch type {
        case .url, .shell:
            return InitialWindowSizeRecommendation(
                widthRatio: 0.66, heightRatio: 0.66,
                aspectRatio: Defaults.defaultWindowAspectRatio,
                sizePresetID: WindowSizePresets.standard.id)
        case .app:
            return InitialWindowSizeRecommendation(
                widthRatio: 0.74, heightRatio: 0.76, aspectRatio: nil,
                sizePresetID: WindowSizePresets.comfortable.id)
        case .finder:
            return InitialWindowSizeRecommendation(
                widthRatio: 0.42, heightRatio: 0.46, aspectRatio: nil,
                sizePresetID: WindowSizePresets.compact.id)
        }
    }
}

public struct DisplaySizeOverride: Codable, Equatable {
    public var displayName: String?
    public var displayIdentifier: String?
    public var windowSizePreset: String?
    public var width: Int
    public var height: Int

    public init(
        displayName: String? = nil, displayIdentifier: String? = nil,
        windowSizePreset: String? = nil, width: Int, height: Int
    ) {
        self.displayName = displayName
        self.displayIdentifier = displayIdentifier
        self.windowSizePreset = windowSizePreset
        self.width = width
        self.height = height
    }
}

public struct Site: Codable, Equatable, Identifiable {
    /// 세션 한정 안정 식별자. 인코딩/디코딩·동등성 비교에서 제외되며,
    /// SwiftUI가 재정렬·이동 후에도 편집 뷰를 올바른 사이트에 고정하는 데 쓴다.
    public let id = UUID()
    public var name: String
    public var url: String
    public var width: Int
    public var height: Int
    public var displayName: String?
    /// 대상 디스플레이의 안정적 고유 ID (CGDisplay UUID 문자열).
    /// displayName과 함께 저장하며, 매칭은 이 값을 우선한다. 동일 모델 외장 모니터가
    /// 여러 대여도 물리 디스플레이별로 다른 값이라 정확히 구분된다. nil이면(구버전 config
    /// 또는 Follow Cursor) displayName으로 폴백한다.
    public var displayIdentifier: String?
    public var windowSizePreset: String?
    public var displaySizeOverrides: [DisplaySizeOverride]
    public var launchType: LaunchType
    public var appPath: String?
    public var script: String?
    public var folderPath: String?
    public var shortcut: String?  // 예: "T", "G" → ⌥T, ⌥G로 실행. nil이면 단축키 없음.

    public init(
        name: String, url: String, width: Int, height: Int,
        displayName: String? = nil, displayIdentifier: String? = nil,
        windowSizePreset: String? = nil,
        displaySizeOverrides: [DisplaySizeOverride] = [],
        launchType: LaunchType = .url, appPath: String? = nil, script: String? = nil,
        folderPath: String? = nil, shortcut: String? = nil
    ) {
        self.name = name
        self.url = url
        self.width = width
        self.height = height
        self.displayName = displayName
        self.displayIdentifier = displayIdentifier
        self.windowSizePreset = windowSizePreset
        self.displaySizeOverrides = displaySizeOverrides
        self.launchType = launchType
        self.appPath = appPath
        self.script = script
        self.folderPath = folderPath
        self.shortcut = shortcut
    }

    private enum CodingKeys: String, CodingKey {
        case name, url, width, height, x, y, displayName, displayIdentifier
        case windowSizePreset, displaySizeOverrides, launchType
        case appPath, script, folderPath, shortcut, hotkey
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        url = try container.decode(String.self, forKey: .url)
        width = try container.decode(Int.self, forKey: .width)
        height = try container.decode(Int.self, forKey: .height)
        // x, y는 기존 JSON 호환을 위해 decode만 하고 무시 (항상 화면 중앙 배치)
        _ = try container.decodeIfPresent(Int.self, forKey: .x)
        _ = try container.decodeIfPresent(Int.self, forKey: .y)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        displayIdentifier = try container.decodeIfPresent(String.self, forKey: .displayIdentifier)
        windowSizePreset = try container.decodeIfPresent(String.self, forKey: .windowSizePreset)
        displaySizeOverrides =
            try container.decodeIfPresent(
                [DisplaySizeOverride].self, forKey: .displaySizeOverrides) ?? []
        launchType = try container.decodeIfPresent(LaunchType.self, forKey: .launchType) ?? .url
        appPath = try container.decodeIfPresent(String.self, forKey: .appPath)
        script = try container.decodeIfPresent(String.self, forKey: .script)
        folderPath = try container.decodeIfPresent(String.self, forKey: .folderPath)
        // "shortcut" 우선, 없으면 "hotkey"에서 마이그레이션
        shortcut =
            try container.decodeIfPresent(String.self, forKey: .shortcut)
            ?? container.decodeIfPresent(String.self, forKey: .hotkey)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(url, forKey: .url)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
        // x, y는 더 이상 저장하지 않음 (항상 화면 중앙 배치)
        try container.encodeIfPresent(displayName, forKey: .displayName)
        try container.encodeIfPresent(displayIdentifier, forKey: .displayIdentifier)
        try container.encodeIfPresent(windowSizePreset, forKey: .windowSizePreset)
        if !displaySizeOverrides.isEmpty {
            try container.encode(displaySizeOverrides, forKey: .displaySizeOverrides)
        }
        try container.encode(launchType, forKey: .launchType)
        try container.encodeIfPresent(appPath, forKey: .appPath)
        try container.encodeIfPresent(script, forKey: .script)
        try container.encodeIfPresent(folderPath, forKey: .folderPath)
        try container.encodeIfPresent(shortcut, forKey: .shortcut)
        // hotkey는 encode하지 않음 (마이그레이션 완료)
    }

    /// id는 세션 한정 식별자이므로 값 동등성 비교에서 제외한다.
    /// (hasChanges 판정·round-trip 테스트가 값 기준으로 동작해야 함)
    public static func == (lhs: Site, rhs: Site) -> Bool {
        lhs.name == rhs.name && lhs.url == rhs.url && lhs.width == rhs.width
            && lhs.height == rhs.height && lhs.displayName == rhs.displayName
            && lhs.displayIdentifier == rhs.displayIdentifier
            && lhs.windowSizePreset == rhs.windowSizePreset
            && lhs.displaySizeOverrides == rhs.displaySizeOverrides
            && lhs.launchType == rhs.launchType && lhs.appPath == rhs.appPath
            && lhs.script == rhs.script && lhs.folderPath == rhs.folderPath
            && lhs.shortcut == rhs.shortcut
    }
}

public struct Config: Codable {
    public var showGuideWindow: Bool
    public var launchAtLogin: Bool
    public var sites: [Site]

    private enum CodingKeys: String, CodingKey {
        case showGuideWindow, showGhostWindow, launchAtLogin, sites
    }

    public init(
        showGuideWindow: Bool = true,
        launchAtLogin: Bool = false, sites: [Site]
    ) {
        self.showGuideWindow = showGuideWindow
        self.launchAtLogin = launchAtLogin
        self.sites = sites
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // "showGuideWindow" 우선, 없으면 "showGhostWindow"에서 마이그레이션
        showGuideWindow =
            try container.decodeIfPresent(Bool.self, forKey: .showGuideWindow)
            ?? container.decodeIfPresent(Bool.self, forKey: .showGhostWindow) ?? true
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        sites = try container.decode([Site].self, forKey: .sites)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(showGuideWindow, forKey: .showGuideWindow)
        try container.encode(launchAtLogin, forKey: .launchAtLogin)
        try container.encode(sites, forKey: .sites)
        // showGhostWindow는 encode하지 않음 (마이그레이션 완료)
    }

    public static let `default` = Config(sites: [
        Site(
            name: "Google", url: "https://www.google.com/", width: 600, height: 400),
        Site(
            name: "GitHub", url: "https://github.com/", width: Defaults.defaultWidth,
            height: Defaults.defaultHeight),
    ])
}
