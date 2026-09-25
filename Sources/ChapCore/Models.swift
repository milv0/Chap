import Foundation

public enum Defaults {
    /// 앱 번들의 CFBundleShortVersionString에서 읽음 (About 창 표시용).
    /// Info.plist / MARKETING_VERSION과 단일 소스로 유지된다.
    public static let appVersion: String =
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
        ?? "1.3.8"
    public static let configPath = NSString(string: "~/.chap.json").expandingTildeInPath
    /// 새로 추가한 사이트의 기본 이름 겸 "아직 미완성" 판별용 센티넬.
    /// placeholder 폐기·필수필드 검증·자동 네이밍 로직이 이 값을 기준으로 동작한다.
    public static let newSiteName = "New Launchable"
    public static let defaultWidth = 800
    public static let defaultHeight = 600
    public static let defaultWindowAspectRatio = 16.0 / 10.0

    /// 도메인 검증용 정규식. 리터럴이라 컴파일 타임에 유효성이 검증된다.
    public static let domainRegex = /^[a-zA-Z0-9._-]+$/
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
    public var reuseExistingWindow: Bool
    public var appPath: String?
    public var script: String?
    public var folderPath: String?
    public var shortcut: String?  // 예: "T", "G" → ⌥T, ⌥G로 실행. nil이면 단축키 없음.

    public init(
        name: String, url: String, width: Int, height: Int,
        displayName: String? = nil, displayIdentifier: String? = nil,
        windowSizePreset: String? = nil,
        displaySizeOverrides: [DisplaySizeOverride] = [],
        launchType: LaunchType = .url, reuseExistingWindow: Bool = false,
        appPath: String? = nil, script: String? = nil, folderPath: String? = nil,
        shortcut: String? = nil
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
        self.reuseExistingWindow = reuseExistingWindow
        self.appPath = appPath
        self.script = script
        self.folderPath = folderPath
        self.shortcut = shortcut
    }

    private enum CodingKeys: String, CodingKey {
        case name, url, width, height, x, y, displayName, displayIdentifier
        case windowSizePreset, displaySizeOverrides, launchType
        case reuseExistingWindow, appPath, script, folderPath, shortcut, hotkey
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
        reuseExistingWindow =
            try container.decodeIfPresent(Bool.self, forKey: .reuseExistingWindow) ?? false
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
        try container.encode(reuseExistingWindow, forKey: .reuseExistingWindow)
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
            && lhs.launchType == rhs.launchType
            && lhs.reuseExistingWindow == rhs.reuseExistingWindow
            && lhs.appPath == rhs.appPath
            && lhs.script == rhs.script && lhs.folderPath == rhs.folderPath
            && lhs.shortcut == rhs.shortcut
    }
}

/// 상태바 아이콘 선택지. rawValue가 config JSON에 저장된다.
public enum StatusBarIconChoice: String, Codable, CaseIterable {
    /// 기존 커스텀 템플릿 아이콘 (StatusBarIcon.png).
    case `default` = "default"
    /// SF Symbols bolt.fill 아이콘.
    case lightning = "lightning"
}

/// 노치 런처 패널의 시각 스타일.
public enum NotchPanelStyle: String, Codable, CaseIterable {
    /// 노치와 이어지는 순수 검정 도크.
    case black = "black"
    /// 하단이 빙하 아랫부분처럼 뾰족한 얼음 그라데이션 도크.
    case iceberg = "iceberg"
    /// 콘텐츠 박스가 Apple Liquid Glass 재질인 도크 (macOS 26+).
    /// 그 이하 버전에서는 black과 동일하게 렌더링된다.
    case glass = "glass"
}

/// 노치 패널의 한 칸에 배치할 수 있는 위젯.
public enum NotchWidget: String, Codable, CaseIterable {
    /// URL 런처 목록.
    case sites = "sites"
    /// 앱 런처 목록.
    case apps = "apps"
    /// Finder 폴더 런처 목록.
    case folders = "folders"
    /// 셸 스크립트 런처 목록.
    case scripts = "scripts"
    /// 스크린샷 선반: 스크린샷 폴더의 최신 이미지를 모아 보여준다.
    case screenshots = "screenshots"
    /// Chap Drop: 떨어뜨린 파일을 보관함에 모아 보여준다.
    case drop = "drop"
    /// 빈 칸.
    case none = "none"

    /// 위젯이 담당하는 launch type. 런처 위젯이 아니면 nil.
    public var launchType: LaunchType? {
        switch self {
        case .sites: return .url
        case .apps: return .app
        case .folders: return .finder
        case .scripts: return .shell
        case .screenshots, .drop, .none: return nil
        }
    }

    /// 노치 패널의 고정 칸 수.
    public static let slotCount = 4

    /// 기본 배치: 4칸에 런처 섹션 순서대로.
    public static let defaultSlots: [NotchWidget] = [.sites, .apps, .folders, .scripts]

    /// 임의 길이 입력을 정확히 4칸으로 정규화한다 (초과는 자르고 부족은 빈 칸).
    public static func normalizedSlots(_ widgets: [NotchWidget]) -> [NotchWidget] {
        let trimmed = widgets.prefix(slotCount)
        return Array(trimmed) + Array(repeating: .none, count: slotCount - trimmed.count)
    }
}

public struct Config: Codable {
    public var showGuideWindow: Bool
    public var launchAtLogin: Bool
    public var optionShortcutsEnabled: Bool
    public var statusBarIcon: StatusBarIconChoice
    /// 상태바 메뉴에서 숨길 launch type 섹션. 숨겨도 ⌥ 단축키는 계속 동작한다.
    public var hiddenMenuLaunchTypes: Set<LaunchType>
    /// 노치 런처 표시 여부. 상태바 NSMenu는 이 값과 무관하게 항상 유지된다.
    public var notchLauncherEnabled: Bool
    /// 노치 패널의 시각 스타일.
    public var notchPanelStyle: NotchPanelStyle
    /// 노치 패널 본체의 하단 불투명도 (0.2~1.0). 상단은 항상 완전 검정이다.
    public var notchPanelOpacity: Double
    /// 노치 패널 콘텐츠 박스(노치 하단 경계 아래)의 배경색. "#RRGGBB".
    /// 상단바 구간은 노치 연장이라 항상 검정으로 유지된다.
    public var notchPanelColorHex: String
    /// 노치 패널 4칸에 배치된 위젯. 항상 정확히 `NotchWidget.slotCount`개다.
    public var notchWidgets: [NotchWidget]
    public var sites: [Site]

    /// 패널 불투명도의 허용 범위. 하한은 텍스트 가독성 하한선이다.
    public static let notchPanelOpacityRange: ClosedRange<Double> = 0.2...1.0
    public static let notchPanelOpacityDefault: Double = 0.6
    public static let notchPanelColorHexDefault = "#000000"

    /// "#RRGGBB" 형식 검증. 형식이 어긋나면 nil.
    public static func validNotchPanelColorHex(_ raw: String?) -> String? {
        guard let raw, raw.count == 7, raw.hasPrefix("#"),
            raw.dropFirst().allSatisfy({ $0.isHexDigit })
        else { return nil }
        return raw.uppercased()
    }

    private enum CodingKeys: String, CodingKey {
        case showGuideWindow, showGhostWindow, launchAtLogin, optionShortcutsEnabled
        case statusBarIcon, hiddenMenuLaunchTypes, notchLauncherEnabled, notchPanelStyle
        case notchPanelOpacity, notchPanelColorHex, notchWidgets
        case sites
    }

    public init(
        showGuideWindow: Bool = true,
        launchAtLogin: Bool = false,
        optionShortcutsEnabled: Bool = true,
        statusBarIcon: StatusBarIconChoice = .default,
        hiddenMenuLaunchTypes: Set<LaunchType> = [],
        notchLauncherEnabled: Bool = false,
        notchPanelStyle: NotchPanelStyle = .black,
        notchPanelOpacity: Double = Config.notchPanelOpacityDefault,
        notchPanelColorHex: String = Config.notchPanelColorHexDefault,
        notchWidgets: [NotchWidget] = NotchWidget.defaultSlots,
        sites: [Site]
    ) {
        self.showGuideWindow = showGuideWindow
        self.launchAtLogin = launchAtLogin
        self.optionShortcutsEnabled = optionShortcutsEnabled
        self.statusBarIcon = statusBarIcon
        self.hiddenMenuLaunchTypes = hiddenMenuLaunchTypes
        self.notchLauncherEnabled = notchLauncherEnabled
        self.notchPanelStyle = notchPanelStyle
        self.notchPanelOpacity = notchPanelOpacity
        self.notchPanelColorHex =
            Config.validNotchPanelColorHex(notchPanelColorHex)
            ?? Config.notchPanelColorHexDefault
        self.notchWidgets = NotchWidget.normalizedSlots(notchWidgets)
        self.sites = sites
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // "showGuideWindow" 우선, 없으면 "showGhostWindow"에서 마이그레이션
        showGuideWindow =
            try container.decodeIfPresent(Bool.self, forKey: .showGuideWindow)
            ?? container.decodeIfPresent(Bool.self, forKey: .showGhostWindow) ?? true
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        optionShortcutsEnabled =
            try container.decodeIfPresent(Bool.self, forKey: .optionShortcutsEnabled) ?? true
        statusBarIcon =
            try container.decodeIfPresent(StatusBarIconChoice.self, forKey: .statusBarIcon)
            ?? .default
        // 키 누락은 빈 집합, 알 수 없는 타입 문자열은 무시한다 (관용 디코딩).
        hiddenMenuLaunchTypes = Set(
            (try container.decodeIfPresent([String].self, forKey: .hiddenMenuLaunchTypes)
                ?? [])
                .compactMap(LaunchType.init(rawValue:)))
        // 값 타입이 어긋나도 설정 전체를 버리지 않고 off로 취급한다 (관용 디코딩).
        notchLauncherEnabled =
            (try? container.decodeIfPresent(Bool.self, forKey: .notchLauncherEnabled)) ?? false
        // 알 수 없는 스타일 문자열은 기본 스타일로 취급한다 (관용 디코딩).
        notchPanelStyle =
            (try? container.decodeIfPresent(String.self, forKey: .notchPanelStyle))
            .flatMap { NotchPanelStyle(rawValue: $0 ?? "") } ?? .black
        // 범위 밖 값은 클램프, 타입이 어긋나면 기본값으로 취급한다 (관용 디코딩).
        let rawOpacity =
            (try? container.decodeIfPresent(Double.self, forKey: .notchPanelOpacity))
            .flatMap { $0 } ?? Config.notchPanelOpacityDefault
        notchPanelOpacity = min(
            max(rawOpacity, Config.notchPanelOpacityRange.lowerBound),
            Config.notchPanelOpacityRange.upperBound)
        // 형식이 어긋난 색은 기본 검정으로 취급한다 (관용 디코딩).
        notchPanelColorHex =
            Config.validNotchPanelColorHex(
                try? container.decodeIfPresent(String.self, forKey: .notchPanelColorHex)
                    .flatMap { $0 })
            ?? Config.notchPanelColorHexDefault
        // 알 수 없는 위젯 이름은 버리고 항상 4칸으로 정규화한다 (관용 디코딩).
        if let rawWidgets = (try? container.decodeIfPresent([String].self, forKey: .notchWidgets))
            .flatMap({ $0 })
        {
            notchWidgets = NotchWidget.normalizedSlots(
                rawWidgets.compactMap(NotchWidget.init(rawValue:)))
        } else {
            notchWidgets = NotchWidget.defaultSlots
        }
        sites = try container.decode([Site].self, forKey: .sites)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(showGuideWindow, forKey: .showGuideWindow)
        try container.encode(launchAtLogin, forKey: .launchAtLogin)
        try container.encode(optionShortcutsEnabled, forKey: .optionShortcutsEnabled)
        try container.encode(statusBarIcon, forKey: .statusBarIcon)
        // Set 순서 비결정성이 config 파일 diff를 만들지 않도록 고정 순서로 encode.
        let hiddenOrdered = LaunchType.allCases
            .filter { hiddenMenuLaunchTypes.contains($0) }
            .map(\.rawValue)
        try container.encode(hiddenOrdered, forKey: .hiddenMenuLaunchTypes)
        try container.encode(notchLauncherEnabled, forKey: .notchLauncherEnabled)
        try container.encode(notchPanelStyle.rawValue, forKey: .notchPanelStyle)
        try container.encode(notchPanelOpacity, forKey: .notchPanelOpacity)
        try container.encode(notchPanelColorHex, forKey: .notchPanelColorHex)
        try container.encode(notchWidgets.map(\.rawValue), forKey: .notchWidgets)
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
