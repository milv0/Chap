import Foundation

public enum Defaults {
    public static let appVersion = "2.2.9"
    public static let configPath = NSString(string: "~/.chap.json").expandingTildeInPath
    public static let defaultWidth = 800
    public static let defaultHeight = 600
    public static let defaultX = 100
    public static let defaultY = 100
    public static let resizeDelay = 0.2
    public static let coldStartDelay = 1.0
    public static let resizeRetries = 40
    public static let retryInterval = 0.3
    public static let domainRegex = try? NSRegularExpression(pattern: "^[a-zA-Z0-9._-]+$")
}

public enum LaunchType: String, Codable, CaseIterable {
    case url
    case app
    case finder
    case shell
}

public struct Site: Codable, Equatable {
    public var name: String
    public var url: String
    public var width: Int
    public var height: Int
    public var x: Int
    public var y: Int
    public var displayName: String?
    public var launchType: LaunchType
    public var appPath: String?
    public var script: String?
    public var folderPath: String?

    public init(
        name: String, url: String, width: Int, height: Int, x: Int, y: Int,
        displayName: String? = nil, launchType: LaunchType = .url,
        appPath: String? = nil, script: String? = nil, folderPath: String? = nil
    ) {
        self.name = name
        self.url = url
        self.width = width
        self.height = height
        self.x = x
        self.y = y
        self.displayName = displayName
        self.launchType = launchType
        self.appPath = appPath
        self.script = script
        self.folderPath = folderPath
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        url = try container.decode(String.self, forKey: .url)
        width = try container.decode(Int.self, forKey: .width)
        height = try container.decode(Int.self, forKey: .height)
        x = try container.decode(Int.self, forKey: .x)
        y = try container.decode(Int.self, forKey: .y)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        launchType = try container.decodeIfPresent(LaunchType.self, forKey: .launchType) ?? .url
        appPath = try container.decodeIfPresent(String.self, forKey: .appPath)
        script = try container.decodeIfPresent(String.self, forKey: .script)
        folderPath = try container.decodeIfPresent(String.self, forKey: .folderPath)
    }
}

public struct Config: Codable {
    public var runInBackground: Bool
    public var showGhostWindow: Bool
    public var sites: [Site]

    public init(runInBackground: Bool = true, showGhostWindow: Bool = true, sites: [Site]) {
        self.runInBackground = runInBackground
        self.showGhostWindow = showGhostWindow
        self.sites = sites
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        runInBackground = try container.decodeIfPresent(Bool.self, forKey: .runInBackground) ?? true
        showGhostWindow = try container.decodeIfPresent(Bool.self, forKey: .showGhostWindow) ?? true
        sites = try container.decode([Site].self, forKey: .sites)
    }

    public static let `default` = Config(sites: [
        Site(
            name: "Google", url: "https://www.google.com/", width: 600, height: 400,
            x: Defaults.defaultX, y: Defaults.defaultY),
        Site(
            name: "GitHub", url: "https://github.com/", width: Defaults.defaultWidth,
            height: Defaults.defaultHeight, x: Defaults.defaultX, y: Defaults.defaultY),
    ])
}
