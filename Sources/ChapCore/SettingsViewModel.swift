import Foundation

/// 설정창이 저장을 요청할 때 넘기는 전체 설정. `Config` 하나를 감싸고, 읽기 편하게 필드를 그대로 노출한다.
public struct SettingsPayload {
    public let config: Config

    public init(config: Config) { self.config = config }

    public var sites: [Site] { config.sites }
    public var showGuideWindow: Bool { config.showGuideWindow }
    public var launchAtLogin: Bool { config.launchAtLogin }
    public var optionShortcutsEnabled: Bool { config.optionShortcutsEnabled }
    public var statusBarIcon: StatusBarIconChoice { config.statusBarIcon }
    public var hiddenMenuLaunchTypes: Set<LaunchType> { config.hiddenMenuLaunchTypes }
    public var notchLauncherEnabled: Bool { config.notchLauncherEnabled }
    public var notchPanelStyle: NotchPanelStyle { config.notchPanelStyle }
    public var notchGlassAppearance: NotchGlassAppearance { config.notchGlassAppearance }
    public var notchGlassMaterial: NotchGlassMaterial { config.notchGlassMaterial }
    public var notchPanelOpacity: Double { config.notchPanelOpacity }
    public var notchPanelColorHex: String { config.notchPanelColorHex }
    public var notchMirrorEnabled: Bool { config.notchMirrorEnabled }
    public var notchQuickNoteEnabled: Bool { config.notchQuickNoteEnabled }
    public var notchCoverScreensEnabled: Bool { config.notchCoverScreensEnabled }
    public var notchQuickNoteShortcut: String? { config.notchQuickNoteShortcut }
    public var coverScreensShortcut: String? { config.coverScreensShortcut }
    public var coverScreensMessage: String? { config.coverScreensMessage }
    public var notchWidgets: [NotchWidget] { config.notchWidgets }
}

public final class SettingsViewModel: ObservableObject {
    @Published public var sites: [Site]
    @Published public var showGuideWindow: Bool
    @Published public var launchAtLogin: Bool
    @Published public var optionShortcutsEnabled: Bool
    @Published public var statusBarIcon: StatusBarIconChoice
    @Published public var hiddenMenuLaunchTypes: Set<LaunchType>
    @Published public var notchLauncherEnabled: Bool
    @Published public var notchPanelStyle: NotchPanelStyle
    @Published public var notchGlassAppearance: NotchGlassAppearance
    @Published public var notchGlassMaterial: NotchGlassMaterial
    @Published public var notchPanelOpacity: Double
    @Published public var notchPanelColorHex: String
    @Published public var notchMirrorEnabled: Bool
    @Published public var notchQuickNoteEnabled: Bool
    @Published public var notchCoverScreensEnabled: Bool
    @Published public var notchQuickNoteShortcut: String?
    @Published public var coverScreensShortcut: String?
    @Published public var coverScreensMessage: String?
    @Published public var notchWidgets: [NotchWidget]
    @Published public var originalSites: [Site]
    @Published public var originalGuide: Bool
    @Published public var originalLogin: Bool
    @Published public var originalOptionShortcutsEnabled: Bool
    @Published public var originalStatusBarIcon: StatusBarIconChoice
    @Published public var originalHiddenMenuLaunchTypes: Set<LaunchType>
    @Published public var originalNotchLauncherEnabled: Bool
    @Published public var originalNotchPanelStyle: NotchPanelStyle
    @Published public var originalNotchGlassAppearance: NotchGlassAppearance
    @Published public var originalNotchGlassMaterial: NotchGlassMaterial
    @Published public var originalNotchPanelOpacity: Double
    @Published public var originalNotchPanelColorHex: String
    @Published public var originalNotchWidgets: [NotchWidget]
    @Published public var originalNotchMirrorEnabled: Bool
    @Published public var originalNotchQuickNoteEnabled: Bool
    @Published public var originalNotchCoverScreensEnabled: Bool
    @Published public var originalNotchQuickNoteShortcut: String?
    @Published public var originalCoverScreensShortcut: String?
    @Published public var originalCoverScreensMessage: String?
    /// 저장 성공 시 true를 반환해야 함. 실패(false) 시 markSaved가 호출되지 않음.
    public var onSave: ((SettingsPayload) -> Bool)?
    private let saveDebouncer: SaveDebouncer

    public var hasChanges: Bool {
        sites != originalSites || showGuideWindow != originalGuide
            || launchAtLogin != originalLogin
            || optionShortcutsEnabled != originalOptionShortcutsEnabled
            || statusBarIcon != originalStatusBarIcon
            || hiddenMenuLaunchTypes != originalHiddenMenuLaunchTypes
            || notchLauncherEnabled != originalNotchLauncherEnabled
            || notchPanelStyle != originalNotchPanelStyle
            || notchGlassAppearance != originalNotchGlassAppearance
            || notchGlassMaterial != originalNotchGlassMaterial
            || notchPanelOpacity != originalNotchPanelOpacity
            || notchPanelColorHex != originalNotchPanelColorHex
            || notchWidgets != originalNotchWidgets
            || notchMirrorEnabled != originalNotchMirrorEnabled
            || notchQuickNoteEnabled != originalNotchQuickNoteEnabled
            || notchCoverScreensEnabled != originalNotchCoverScreensEnabled
            || notchQuickNoteShortcut != originalNotchQuickNoteShortcut
            || coverScreensShortcut != originalCoverScreensShortcut
            || coverScreensMessage != originalCoverScreensMessage
    }

    public func markSaved() {
        originalSites = sites
        markGlobalsSaved()
    }

    /// General/Notch 즉시 저장 성공 후 global baseline만 갱신한다.
    /// 편집 중인 site draft는 `originalSites`와 분리해 unsaved 상태를 보존한다.
    public func markGlobalsSaved() {
        originalGuide = showGuideWindow
        originalLogin = launchAtLogin
        originalOptionShortcutsEnabled = optionShortcutsEnabled
        originalStatusBarIcon = statusBarIcon
        originalHiddenMenuLaunchTypes = hiddenMenuLaunchTypes
        originalNotchLauncherEnabled = notchLauncherEnabled
        originalNotchPanelStyle = notchPanelStyle
        originalNotchGlassAppearance = notchGlassAppearance
        originalNotchGlassMaterial = notchGlassMaterial
        originalNotchPanelOpacity = notchPanelOpacity
        originalNotchPanelColorHex = notchPanelColorHex
        originalNotchWidgets = notchWidgets
        originalNotchMirrorEnabled = notchMirrorEnabled
        originalNotchQuickNoteEnabled = notchQuickNoteEnabled
        originalNotchCoverScreensEnabled = notchCoverScreensEnabled
        originalNotchQuickNoteShortcut = notchQuickNoteShortcut
        originalCoverScreensShortcut = coverScreensShortcut
        originalCoverScreensMessage = coverScreensMessage
    }

    /// 유효한 현재 편집 상태를 debounce해 자동 저장한다.
    public func scheduleAutoSave() {
        saveDebouncer.schedule { [weak self] in
            guard let self else { return }
            let config = self.config
            guard validateConfig(config).isValid else { return }
            _ = self.persistCurrentState()
        }
    }

    public func flushPendingSave() {
        saveDebouncer.flush()
    }

    public func cancelPendingSave() {
        saveDebouncer.cancel()
    }

    @discardableResult
    public func persistCurrentState() -> Bool {
        let saved = onSave?(SettingsPayload(config: config)) ?? true
        if saved { markSaved() }
        return saved
    }

    /// 지금 편집 중인 값 전체를 `Config`로. 저장·검증·Export가 모두 이것을 쓴다.
    /// `notchCollapsedWidgets`는 설정창이 다루지 않는 이 Mac의 표시 선택이라 기본값(빈 목록)으로 두고,
    /// AppDelegate가 저장 직전에 현재 값을 다시 채운다.
    public var config: Config {
        Config(
            showGuideWindow: showGuideWindow,
            launchAtLogin: launchAtLogin,
            optionShortcutsEnabled: optionShortcutsEnabled,
            statusBarIcon: statusBarIcon,
            hiddenMenuLaunchTypes: hiddenMenuLaunchTypes,
            notchLauncherEnabled: notchLauncherEnabled,
            notchPanelStyle: notchPanelStyle,
            notchGlassAppearance: notchGlassAppearance,
            notchGlassMaterial: notchGlassMaterial,
            notchPanelOpacity: notchPanelOpacity,
            notchPanelColorHex: notchPanelColorHex,
            notchMirrorEnabled: notchMirrorEnabled,
            notchQuickNoteEnabled: notchQuickNoteEnabled,
            notchCoverScreensEnabled: notchCoverScreensEnabled,
            notchQuickNoteShortcut: notchQuickNoteShortcut,
            coverScreensShortcut: coverScreensShortcut,
            coverScreensMessage: coverScreensMessage,
            notchWidgets: notchWidgets,
            sites: sites)
    }

    /// 저장된 `Config`로 뷰 모델을 만든다. 필드를 하나씩 옮겨 적는 긴 호출을 대신한다.
    public convenience init(config: Config, saveDebouncer: SaveDebouncer = SaveDebouncer()) {
        self.init(
            sites: config.sites,
            showGuideWindow: config.showGuideWindow,
            launchAtLogin: config.launchAtLogin,
            optionShortcutsEnabled: config.optionShortcutsEnabled,
            statusBarIcon: config.statusBarIcon,
            hiddenMenuLaunchTypes: config.hiddenMenuLaunchTypes,
            notchLauncherEnabled: config.notchLauncherEnabled,
            notchPanelStyle: config.notchPanelStyle,
            notchGlassAppearance: config.notchGlassAppearance,
            notchGlassMaterial: config.notchGlassMaterial,
            notchPanelOpacity: config.notchPanelOpacity,
            notchPanelColorHex: config.notchPanelColorHex,
            notchMirrorEnabled: config.notchMirrorEnabled,
            notchQuickNoteEnabled: config.notchQuickNoteEnabled,
            notchCoverScreensEnabled: config.notchCoverScreensEnabled,
            notchQuickNoteShortcut: config.notchQuickNoteShortcut,
            coverScreensShortcut: config.coverScreensShortcut,
            coverScreensMessage: config.coverScreensMessage,
            notchWidgets: config.notchWidgets,
            saveDebouncer: saveDebouncer)
    }

    public init(
        sites: [Site], showGuideWindow: Bool = true,
        launchAtLogin: Bool = false,
        optionShortcutsEnabled: Bool = true,
        statusBarIcon: StatusBarIconChoice = .default,
        hiddenMenuLaunchTypes: Set<LaunchType> = [],
        notchLauncherEnabled: Bool = false,
        notchPanelStyle: NotchPanelStyle = .custom,
        notchGlassAppearance: NotchGlassAppearance = .system,
        notchGlassMaterial: NotchGlassMaterial = .regular,
        notchPanelOpacity: Double = Config.notchPanelOpacityDefault,
        notchPanelColorHex: String = Config.notchPanelColorHexDefault,
        notchMirrorEnabled: Bool = true,
        notchQuickNoteEnabled: Bool = true,
        notchCoverScreensEnabled: Bool = true,
        notchQuickNoteShortcut: String? = QuickNoteShortcutPolicy.defaultKey,
        coverScreensShortcut: String? = CoverScreensPolicy.defaultShortcut,
        coverScreensMessage: String? = nil,
        notchWidgets: [NotchWidget] = NotchWidget.defaultSlots,
        saveDebouncer: SaveDebouncer = SaveDebouncer()
    ) {
        self.sites = sites
        self.showGuideWindow = showGuideWindow
        self.launchAtLogin = launchAtLogin
        self.optionShortcutsEnabled = optionShortcutsEnabled
        self.statusBarIcon = statusBarIcon
        self.hiddenMenuLaunchTypes = hiddenMenuLaunchTypes
        self.notchLauncherEnabled = notchLauncherEnabled
        self.notchPanelStyle = notchPanelStyle
        self.notchGlassAppearance = notchGlassAppearance
        self.notchGlassMaterial = notchGlassMaterial
        self.notchPanelOpacity = notchPanelOpacity
        self.notchPanelColorHex = notchPanelColorHex
        self.notchMirrorEnabled = notchMirrorEnabled
        self.notchQuickNoteEnabled = notchQuickNoteEnabled
        self.notchCoverScreensEnabled = notchCoverScreensEnabled
        self.notchQuickNoteShortcut = QuickNoteShortcutPolicy.normalized(notchQuickNoteShortcut)
        self.coverScreensShortcut = QuickNoteShortcutPolicy.normalized(coverScreensShortcut)
        self.coverScreensMessage = CoverScreensPolicy.cleanedMessage(coverScreensMessage)
        self.notchWidgets = NotchWidget.normalizedSlots(notchWidgets)
        self.originalSites = sites
        self.originalGuide = showGuideWindow
        self.originalLogin = launchAtLogin
        self.originalOptionShortcutsEnabled = optionShortcutsEnabled
        self.originalStatusBarIcon = statusBarIcon
        self.originalHiddenMenuLaunchTypes = hiddenMenuLaunchTypes
        self.originalNotchLauncherEnabled = notchLauncherEnabled
        self.originalNotchPanelStyle = notchPanelStyle
        self.originalNotchGlassAppearance = notchGlassAppearance
        self.originalNotchGlassMaterial = notchGlassMaterial
        self.originalNotchPanelOpacity = notchPanelOpacity
        self.originalNotchPanelColorHex = notchPanelColorHex
        self.originalNotchMirrorEnabled = notchMirrorEnabled
        self.originalNotchQuickNoteEnabled = notchQuickNoteEnabled
        self.originalNotchCoverScreensEnabled = notchCoverScreensEnabled
        self.originalNotchQuickNoteShortcut = QuickNoteShortcutPolicy.normalized(
            notchQuickNoteShortcut)
        self.originalCoverScreensShortcut = QuickNoteShortcutPolicy.normalized(coverScreensShortcut)
        self.originalCoverScreensMessage = CoverScreensPolicy.cleanedMessage(coverScreensMessage)
        self.originalNotchWidgets = NotchWidget.normalizedSlots(notchWidgets)
        self.saveDebouncer = saveDebouncer
    }
}
