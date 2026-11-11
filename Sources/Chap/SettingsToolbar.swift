import Cocoa
import Combine

// MARK: - Settings tabs

/// Settings 창의 탭. 순서가 툴바 순서다.
enum SettingsTab: String, Hashable, CaseIterable {
    case launchables
    case general
    case notch
    case tools

    var title: String {
        switch self {
        case .launchables: return "Launchers"
        case .general: return "General"
        case .notch: return "Notch"
        case .tools: return "Tools"
        }
    }

    var symbol: String {
        switch self {
        case .launchables: return "square.grid.2x2"
        case .general: return "gearshape"
        case .notch: return "macbook"
        case .tools: return "wand.and.stars"
        }
    }
}

/// General 탭 아래 앱 도구(안내·Q&A·더보기)가 Settings 본문에 맡기는 일.
/// 시트·가져오기처럼 본문 상태가 필요한 일이라 본문이 처리한다.
enum SettingsAppAction {
    case guide
    case qa
    case importFile
    case pasteJSON
    case export
    case reportBug
    case restart
    case uninstall
}

/// AppKit 툴바와 SwiftUI 본문이 함께 보는 탭 선택. 어느 쪽에서 바꿔도 다른 쪽이 따라간다.
final class SettingsNavigation: ObservableObject {
    @Published var tab: SettingsTab

    init(tab: SettingsTab = .launchables) {
        self.tab = tab
    }
}

// MARK: - Toolbar

/// macOS 설정 창의 표준 툴바(아이콘 위 이름, 제목 막대 안). 탭을 고르면 창 제목도 그 탭 이름이 된다.
/// Apple 설정 창처럼 툴바에는 탭만 둔다. 안내·Q&A·가져오기 같은 도구는 General 탭 아래에 있다.
final class SettingsToolbarController: NSObject, NSToolbarDelegate {
    private enum Item {
        static func tab(_ tab: SettingsTab) -> NSToolbarItem.Identifier {
            NSToolbarItem.Identifier("ChapSettingsTab.\(tab.rawValue)")
        }

        static func tab(for identifier: NSToolbarItem.Identifier) -> SettingsTab? {
            SettingsTab.allCases.first { self.tab($0) == identifier }
        }
    }

    let navigation: SettingsNavigation
    private let toolbar = NSToolbar(identifier: "ChapSettingsToolbar")
    private weak var window: NSWindow?
    private var tabObserver: AnyCancellable?

    init(navigation: SettingsNavigation) {
        self.navigation = navigation
        super.init()
        toolbar.delegate = self
        toolbar.displayMode = .iconAndLabel
        toolbar.allowsUserCustomization = false
    }

    func install(in window: NSWindow) {
        self.window = window
        window.toolbarStyle = .preference
        window.toolbar = toolbar
        apply(navigation.tab)
        // 본문(사이드바·노치 제목 클릭 등)에서 탭을 바꿔도 툴바 선택과 제목이 따라온다.
        tabObserver = navigation.$tab.removeDuplicates().sink { [weak self] tab in
            self?.apply(tab)
        }
    }

    private func apply(_ tab: SettingsTab) {
        toolbar.selectedItemIdentifier = Item.tab(tab)
        window?.title = tab.title
    }

    @objc private func selectTab(_ sender: NSToolbarItem) {
        guard let tab = Item.tab(for: sender.itemIdentifier), tab != navigation.tab else { return }
        navigation.tab = tab
    }

    // MARK: NSToolbarDelegate

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        SettingsTab.allCases.map(Item.tab)
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        SettingsTab.allCases.map(Item.tab)
    }

    func toolbar(
        _ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        guard let tab = Item.tab(for: identifier) else { return nil }
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = tab.title
        item.image = NSImage(systemSymbolName: tab.symbol, accessibilityDescription: tab.title)
        item.target = self
        item.action = #selector(selectTab(_:))
        return item
    }
}
