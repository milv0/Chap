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
    public let label: String
    public let widthRatio: Double
    public let heightRatio: Double
    public let aspectRatio: Double?

    public var id: String { label }

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
        label: "Compact", widthRatio: 0.42, heightRatio: 0.46, aspectRatio: nil)
    public static let standard = WindowSizePreset(
        label: "Standard", widthRatio: 0.66, heightRatio: 0.66,
        aspectRatio: Defaults.defaultWindowAspectRatio)
    public static let comfortable = WindowSizePreset(
        label: "Comfortable", widthRatio: 0.74, heightRatio: 0.76, aspectRatio: nil)
    public static let wide = WindowSizePreset(
        label: "Wide", widthRatio: 0.66, heightRatio: 0.56, aspectRatio: nil)
    public static let tall = WindowSizePreset(
        label: "Tall", widthRatio: 0.38, heightRatio: 0.80, aspectRatio: nil)
    public static let workspace = WindowSizePreset(
        label: "Workspace", widthRatio: 0.82, heightRatio: 0.82, aspectRatio: nil)

    public static let all = [compact, standard, comfortable, wide, tall, workspace]
}

public struct InitialWindowSizeRecommendation: Equatable {
    public let widthRatio: Double
    public let heightRatio: Double
    public let aspectRatio: Double?
}

public enum InitialWindowSizeRecommendations {
    public static func recommendation(for type: LaunchType) -> InitialWindowSizeRecommendation {
        switch type {
        case .url, .shell:
            return InitialWindowSizeRecommendation(
                widthRatio: 0.66, heightRatio: 0.66,
                aspectRatio: Defaults.defaultWindowAspectRatio)
        case .app:
            return InitialWindowSizeRecommendation(
                widthRatio: 0.74, heightRatio: 0.76, aspectRatio: nil)
        case .finder:
            return InitialWindowSizeRecommendation(
                widthRatio: 0.42, heightRatio: 0.46, aspectRatio: nil)
        }
    }
}

public struct Site: Codable, Equatable {
    public var name: String
    public var url: String
    public var width: Int
    public var height: Int
    public var displayName: String?
    public var launchType: LaunchType
    public var appPath: String?
    public var script: String?
    public var folderPath: String?
    public var shortcut: String?  // 예: "T", "G" → ⌥T, ⌥G로 실행. nil이면 단축키 없음.

    public init(
        name: String, url: String, width: Int, height: Int,
        displayName: String? = nil, launchType: LaunchType = .url,
        appPath: String? = nil, script: String? = nil, folderPath: String? = nil,
        shortcut: String? = nil
    ) {
        self.name = name
        self.url = url
        self.width = width
        self.height = height
        self.displayName = displayName
        self.launchType = launchType
        self.appPath = appPath
        self.script = script
        self.folderPath = folderPath
        self.shortcut = shortcut
    }

    private enum CodingKeys: String, CodingKey {
        case name, url, width, height, x, y, displayName, launchType
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
        try container.encode(launchType, forKey: .launchType)
        try container.encodeIfPresent(appPath, forKey: .appPath)
        try container.encodeIfPresent(script, forKey: .script)
        try container.encodeIfPresent(folderPath, forKey: .folderPath)
        try container.encodeIfPresent(shortcut, forKey: .shortcut)
        // hotkey는 encode하지 않음 (마이그레이션 완료)
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
