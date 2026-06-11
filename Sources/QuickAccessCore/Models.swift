import Foundation

public enum Defaults {
    public static let appVersion = "2.2.8"
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

public struct Site: Codable, Equatable {
    public var name: String
    public var url: String
    public var width: Int
    public var height: Int
    public var x: Int
    public var y: Int
    public var displayName: String?

    public init(name: String, url: String, width: Int, height: Int, x: Int, y: Int, displayName: String? = nil) {
        self.name = name
        self.url = url
        self.width = width
        self.height = height
        self.x = x
        self.y = y
        self.displayName = displayName
    }
}

public struct Config: Codable {
    public var runInBackground: Bool
    public var alwaysCenter: Bool
    public var sites: [Site]

    public init(runInBackground: Bool = true, alwaysCenter: Bool = false, sites: [Site]) {
        self.runInBackground = runInBackground
        self.alwaysCenter = alwaysCenter
        self.sites = sites
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        runInBackground = try container.decodeIfPresent(Bool.self, forKey: .runInBackground) ?? true
        alwaysCenter = try container.decodeIfPresent(Bool.self, forKey: .alwaysCenter) ?? false
        sites = try container.decode([Site].self, forKey: .sites)
    }

    public static let `default` = Config(sites: [
        Site(name: "Google", url: "https://www.google.com/", width: 600, height: 400, x: Defaults.defaultX, y: Defaults.defaultY),
        Site(name: "GitHub", url: "https://github.com/", width: Defaults.defaultWidth, height: Defaults.defaultHeight, x: Defaults.defaultX, y: Defaults.defaultY),
    ])
}
