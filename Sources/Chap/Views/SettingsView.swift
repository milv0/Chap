import Cocoa
import SwiftUI
import UniformTypeIdentifiers
import os

struct SettingsView: View {
    /// AppKit이 강제하는 최소 크기. 모든 본문은 이 안에서 스크롤한다.
    static let minimumSize = CGSize(width: 720, height: 560)
    /// 처음 열 때 충분한 세로 공간을 주되 이후에는 minimumSize까지 줄일 수 있다.
    static let initialSize = CGSize(width: 720, height: 660)

    /// 렌더 도구에서 최소 크기의 launcher 상세와 특정 탭을 바로 보여 준다.
    static var previewSelectedIndex: Int?
    static var previewTab: String?

    /// 노치 제목 클릭 등에서 특정 launch type을 보여 달라는 요청. object는 rawValue.
    static let focusLaunchType = Notification.Name("ChapSettingsFocusLaunchType")
    /// 메뉴·노치의 Edit Layout이 그 Layout을 보여 달라는 요청. object는 UUID,
    /// nil이면 Layouts 섹션만 고른다(노치 제목 클릭에서 저장된 Layout이 없을 때).
    static let focusLayout = Notification.Name("ChapSettingsFocusLayout")

    @ObservedObject var vm: SettingsViewModel
    @ObservedObject var updateController: UpdateController
    @ObservedObject var layoutLibrary: LayoutLibrary
    var layoutActions = LayoutSettingsActions()
    /// 사이드바에서 고른 Layout. 사이트 선택(selectedIndex)과 동시에 있지 않는다.
    @State private var selectedLayoutID: UUID?
    /// Layouts 섹션 제목을 눌러 "+"가 새 캡처를 뜻하는 상태.
    @State private var isLayoutsFocused = false
    /// 연결된 디스플레이. 모니터를 꽂거나 뽑으면 갱신한다.
    @State private var connectedDisplays = LayoutDisplay.connected()
    /// 탭 선택. 창 툴바(AppKit)와 함께 본다. 렌더 도구는 `previewTab`으로 첫 탭을 고른다.
    @ObservedObject var navigation = SettingsNavigation(
        tab: SettingsTab(rawValue: SettingsView.previewTab ?? "") ?? .launchables)
    @State private var selectedIndex: Int? = SettingsView.previewSelectedIndex
    /// 사이드바에서 마지막으로 고른 섹션(URL·App·Finder). "+"가 이 섹션에 항목을 만든다.
    /// 섹션 제목이나 그 섹션의 항목을 누르면 바뀐다.
    @State private var focusedLaunchType: LaunchType = .url
    @State private var showDeleteAlert = false
    @State private var showGuide = false
    @State private var isGuideEnglish = false
    @State private var showPasteJSON = false
    @State private var pasteJSONText = ""
    @State private var dropTargeted = false
    @State private var isAddingNew = false
    /// addSite로 갓 추가된, 아직 이름을 정하지 않은 사이트의 id.
    /// 선택이 벗어날 때 이 사이트가 여전히 placeholder면 폐기한다.
    @State private var pendingNewSiteID: UUID?
    @State private var searchText = ""
    @State private var suppressNextSelectionSave = false
    @FocusState private var searchFocused: Bool

    private var selectedTab: SettingsTab {
        get { navigation.tab }
        nonmutating set { navigation.tab = newValue }
    }

    var body: some View {
        selectedContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DS.surfaceBg)
            .background { guideShortcut }
            .onChange(of: selectedTab) { oldValue, _ in
                vm.flushPendingSave()
                if oldValue == .tools {
                    NotificationCenter.default.post(
                        name: ToolsSettingsView.flushPendingSave, object: nil)
                }
                searchFocused = false
            }
            .onChange(of: selectedIndex) { oldValue, newValue in
                if let newValue, newValue < vm.sites.count {
                    focusedLaunchType = vm.sites[newValue].launchType
                    selectedLayoutID = nil
                    isLayoutsFocused = false
                }
                handleSelectionChange(from: oldValue, to: newValue)
            }
            .onReceive(NotificationCenter.default.publisher(for: Self.focusLaunchType)) { note in
                guard let raw = note.object as? String, let type = LaunchType(rawValue: raw) else {
                    return
                }
                focus(on: type)
            }
            .onReceive(NotificationCenter.default.publisher(for: Self.focusLayout)) { note in
                searchText = ""
                if let id = note.object as? UUID {
                    selectLayout(id)
                } else {
                    selectedTab = .launchables
                    selectedIndex = nil
                    selectedLayoutID = nil
                    isLayoutsFocused = true
                }
            }
            .onChange(of: layoutLibrary.layouts.map(\.id)) { oldIDs, ids in
                // 지운 Layout을 보고 있었으면 이웃 Layout으로 옮긴다 (사이트 삭제와 같은 동작).
                guard let selected = selectedLayoutID, !ids.contains(selected) else { return }
                let oldIndex = oldIDs.firstIndex(of: selected) ?? 0
                selectedLayoutID = ids.isEmpty ? nil : ids[min(oldIndex, ids.count - 1)]
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: NSApplication.didChangeScreenParametersNotification)
            ) { _ in
                connectedDisplays = LayoutDisplay.connected()
            }
            .alert("Delete launcher?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) { removeSite() }
                Button("Cancel", role: .cancel) {}
            } message: {
                if let idx = selectedIndex, idx < vm.sites.count {
                    Text("This will remove the launcher \"\(vm.sites[idx].name)\".")
                }
            }
            .sheet(isPresented: $showGuide) {
                SettingsGuideSheet(
                    isGuideEnglish: $isGuideEnglish,
                    onClose: { showGuide = false },
                    onOpenQA: { openQAFromGuide() }
                )
            }
            .alert("Validation Error", isPresented: $emptyFieldAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(emptyFieldMessage)
            }
            .sheet(isPresented: $showPasteJSON) {
                SettingsPasteJSONSheet(
                    pasteJSONText: $pasteJSONText,
                    onCancel: { showPasteJSON = false },
                    onApply: { json in
                        SettingsConfigTransfer.applyJSONString(
                            json, vm: vm, onSuccess: handleSuccessfulImport)
                    }
                )
            }
            .onDisappear { vm.flushPendingSave() }
            .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { providers in
                handleConfigDrop(providers)
            }
            .overlay(
                dropTargeted
                    ? RoundedRectangle(cornerRadius: DS.radius)
                        .stroke(DS.accent, lineWidth: 3)
                        .padding(4)
                    : nil
            )
    }

    // MARK: - Navigation

    /// ⌘/는 어느 탭에서나 안내를 연다(툴바 아이콘과 같은 일).
    private var guideShortcut: some View {
        Button("") { showGuide = true }
            .keyboardShortcut("/", modifiers: .command)
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
    }

    /// General 탭 아래 앱 도구. 시트·가져오기처럼 본문 상태가 필요한 일이라 여기서 처리한다.
    private func handleAppAction(_ action: SettingsAppAction) {
        switch action {
        case .guide: showGuide = true
        case .qa: openQA()
        case .importFile:
            SettingsConfigTransfer.importConfig(vm: vm, onSuccess: handleSuccessfulImport)
        case .pasteJSON:
            pasteJSONText = ""
            showPasteJSON = true
        case .export: SettingsConfigTransfer.exportConfig(vm: vm)
        case .reportBug: reportBug()
        case .restart: restartApp()
        case .uninstall: uninstallApp()
        }
    }

    private var selectedContent: some View {
        Group {
            switch selectedTab {
            case .launchables:
                HStack(spacing: 0) {
                    sidebar
                    Divider()
                    mainPanel
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background { siteSelectionShortcuts }
                }
            case .general:
                GeneralSettingsView(
                    vm: vm, updateController: updateController, onSave: saveGlobals,
                    onAppAction: handleAppAction)
            case .notch:
                NotchSettingsView(vm: vm, onSave: saveGlobals)
            case .tools:
                ToolsSettingsView(vm: vm, onSave: saveGlobals)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(DS.textTertiary)
                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(DS.captionFont)
                    .focused($searchFocused)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(DS.surfaceBg)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .onTapGesture { searchFocused = true }

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(LaunchType.allCases, id: \.self) { type in
                        let indices = vm.sites.indices.filter {
                            vm.sites[$0].launchType == type
                                && (searchText.isEmpty
                                    || vm.sites[$0].name.localizedCaseInsensitiveContains(
                                        searchText))
                        }
                        // 검색 중이 아니면 항목이 없는 타입도 섹션을 유지해,
                        // 네 가지 실행 타입을 사이드바에서 바로 추가할 수 있게 한다.
                        if !indices.isEmpty || searchText.isEmpty {
                            // 제목 옆 (n/한도) 카운트로 타입별 한도를 상시 보여준다.
                            // 제목을 누르면 이 섹션이 "+"의 대상이 된다.
                            let isFocusedSection =
                                focusedLaunchType == type && !isLayoutsFocused
                            HStack(spacing: 4) {
                                Text(typeSectionTitle(type))
                                    .fontWeight(isFocusedSection ? .semibold : .regular)
                                    .foregroundColor(
                                        isFocusedSection ? DS.accent : DS.textSecondary)
                                Text(
                                    "(\(SiteCountLimitPolicy.count(of: type, in: vm.sites))"
                                        + "/\(SiteCountLimitPolicy.limit(for: type)))"
                                )
                                .foregroundColor(DS.textTertiary)
                                .monospacedDigit()
                                Spacer(minLength: 0)
                            }
                            .font(DS.captionFont)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(isFocusedSection ? DS.accentSoft : Color.clear)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                focusSection(type)
                            }
                            .focusable(interactions: .activate)
                            .onKeyPress(.space) {
                                focusSection(type)
                                return .handled
                            }
                            .onKeyPress(.return) {
                                focusSection(type)
                                return .handled
                            }
                            .padding(.top, 5)
                            .accessibilityElement(children: .combine)
                            .accessibilityAddTraits(
                                isFocusedSection ? [.isButton, .isSelected] : .isButton
                            )
                            .accessibilityAction { focusSection(type) }
                            .accessibilityHint("New items from + are added to this section")
                            if indices.isEmpty {
                                SidebarAddRow(label: "Add \(typeSectionTitle(type))") {
                                    addSite(type: type)
                                }
                            }
                            ForEach(indices, id: \.self) { i in
                                SidebarItem(
                                    icon: sidebarIcon(for: vm.sites[i]),
                                    name: vm.sites[i].name,
                                    badge: vm.sites[i].shortcut.map { "⌥ \($0)" },
                                    isSelected: selectedIndex == i
                                )
                                .contentShape(Rectangle())
                                .onTapGesture { selectSite(i) }
                                .focusable(interactions: .activate)
                                .onKeyPress(.space) {
                                    selectSite(i)
                                    return .handled
                                }
                                .onKeyPress(.return) {
                                    selectSite(i)
                                    return .handled
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel(vm.sites[i].name)
                                .accessibilityAddTraits(
                                    selectedIndex == i ? [.isButton, .isSelected] : .isButton
                                )
                                .accessibilityAction { selectSite(i) }
                                .draggable(String(i)) {
                                    Text(vm.sites[i].name)
                                        .padding(8)
                                        .background(DS.cardBg)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                .onDrop(
                                    of: [.plainText],
                                    delegate: SidebarDropDelegate(
                                        currentIndex: i,
                                        sites: $vm.sites,
                                        selectedIndex: $selectedIndex,
                                        onDrop: { _ = save() }
                                    ))
                            }
                        }
                    }
                    SettingsLayoutsSection(
                        layouts: layoutLibrary.layouts,
                        selectedID: selectedLayoutID,
                        isFocused: isLayoutsFocused,
                        searchText: searchText,
                        onFocusSection: {
                            isLayoutsFocused = true
                            selectedTab = .launchables
                            selectedIndex = nil
                            selectedLayoutID = nil
                        },
                        onSelect: selectLayout,
                        onCapture: layoutActions.capture)
                }
                .padding(DS.spacingSmall)
            }
            Divider()
            sidebarControls
        }
        .frame(width: 210)
    }

    // MARK: - Main Panel

    /// Keeps editor writes attached to the selected launcher's stable identity.
    /// If import or deletion removes it while AppKit is ending text editing, late writes are ignored.
    private func siteBinding(id: UUID, fallback: Site) -> Binding<Site> {
        Binding(
            get: {
                vm.sites.first(where: { $0.id == id }) ?? fallback
            },
            set: { updatedSite in
                guard let index = vm.sites.firstIndex(where: { $0.id == id }) else { return }
                vm.sites[index] = updatedSite
            }
        )
    }

    private var mainPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let layoutID = selectedLayoutID,
                layoutLibrary.layout(id: layoutID) != nil
            {
                LayoutDetailView(
                    library: layoutLibrary, layoutID: layoutID,
                    displays: connectedDisplays, actions: layoutActions
                )
                .id(layoutID)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let idx = selectedIndex, idx < vm.sites.count {
                let selectedSite = vm.sites[idx]
                SiteConfigView(
                    site: siteBinding(id: selectedSite.id, fallback: selectedSite),
                    isNew: isAddingNew,
                    quickNoteShortcut: vm.notchQuickNoteShortcut,
                    coverScreensShortcut: vm.coverScreensShortcut,
                    otherSites: vm.sites.filter { $0.id != selectedSite.id },
                    onSave: {
                        vm.cancelPendingSave()
                        return save(showAlerts: true)
                    }
                )
                .id(selectedSite.id)
                .onChange(of: vm.sites) { _, _ in
                    if !vm.isApplyingImportedConfig { vm.scheduleAutoSave() }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 28))
                        .foregroundColor(DS.textTertiary)
                    Text(
                        isLayoutsFocused
                            ? (layoutLibrary.layouts.isEmpty
                                ? "Press + to capture a layout" : "Select a layout")
                            : "Select a launcher to configure"
                    )
                    .font(DS.bodyFont)
                    .foregroundColor(DS.textSecondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            }

        }
    }

    // MARK: - Sidebar controls

    private var sidebarControls: some View {
        HStack(spacing: 4) {
            ToolbarIconButton(
                icon: "plus", color: DS.textSecondary,
                accessibilityLabel: isLayoutsFocused
                    ? "Capture Layout" : "Add \(typeSectionTitle(focusedLaunchType)) item",
                action: { addSite() },
                disabled: !canAddFocusedItem
            )
            .help(
                isLayoutsFocused
                    ? (layoutLibrary.canAdd
                        ? "Capture Layout (⌘N)" : "Layouts are full (4/4)")
                    : (canAddFocusedItem
                        ? "Add to \(typeSectionTitle(focusedLaunchType)) (⌘N)"
                        : "\(typeSectionTitle(focusedLaunchType)) is full "
                            + "(\(SiteCountLimitPolicy.limit(for: focusedLaunchType))/\(SiteCountLimitPolicy.limit(for: focusedLaunchType)))")
            )
            ToolbarIconButton(
                icon: "minus", color: DS.textSecondary,
                accessibilityLabel: selectedLayoutID == nil ? "Remove launchable" : "Remove layout",
                action: {
                    selectedTab = .launchables
                    if let id = selectedLayoutID {
                        layoutActions.remove(id)
                    } else {
                        showDeleteAlert = true
                    }
                },
                disabled: selectedIndex == nil && selectedLayoutID == nil)

            Spacer()

            ToolbarIconButton(
                icon: "chevron.up", color: DS.textSecondary,
                accessibilityLabel: "Move up",
                action: {
                    selectedTab = .launchables
                    moveSiteUp()
                },
                disabled: !canMoveUp)
            ToolbarIconButton(
                icon: "chevron.down", color: DS.textSecondary,
                accessibilityLabel: "Move down",
                action: {
                    selectedTab = .launchables
                    moveSiteDown()
                },
                disabled: !canMoveDown)
        }
        .padding(.horizontal, 8)
        .frame(width: 210, height: 40)
    }

    private var canAddFocusedItem: Bool {
        if isLayoutsFocused { return layoutLibrary.canAdd }
        return SiteCountLimitPolicy.canAdd(focusedLaunchType, to: vm.sites)
    }

    // MARK: - Keyboard Shortcuts

    private var sidebarSiteIndices: [Int] {
        LaunchType.allCases.flatMap { type in
            vm.sites.indices.filter { vm.sites[$0].launchType == type }
        }
    }

    @ViewBuilder
    private var siteSelectionShortcuts: some View {
        ForEach(Array(sidebarSiteIndices.prefix(9).enumerated()), id: \.element) {
            shortcutIndex, siteIndex in
            Button("") { selectedIndex = siteIndex }
                .keyboardShortcut(
                    KeyEquivalent(Character("\(shortcutIndex + 1)")), modifiers: .command
                )
                .frame(width: 0, height: 0)
                .opacity(0)
        }
        Button("") { searchFocused = true }
            .keyboardShortcut("f", modifiers: .command)
            .frame(width: 0, height: 0)
            .opacity(0)
        Button("") { addSite() }
            .keyboardShortcut("n", modifiers: .command)
            .frame(width: 0, height: 0)
            .opacity(0)
        Button("") { _ = save(showAlerts: true) }
            .keyboardShortcut("s", modifiers: .command)
            .frame(width: 0, height: 0)
            .opacity(0)
    }

    /// Launchers 탭으로 가서 그 타입의 첫 항목을 선택한다. 항목이 없으면 탭만 연다.
    private func focus(on type: LaunchType) {
        searchText = ""
        selectedTab = .launchables
        focusedLaunchType = type
        if let first = vm.sites.indices.first(where: { vm.sites[$0].launchType == type }) {
            selectedIndex = first
        }
    }

    // MARK: - Helpers

    private func handleSelectionChange(from oldValue: Int?, to newValue: Int?) {
        vm.flushPendingSave()
        if suppressNextSelectionSave {
            suppressNextSelectionSave = false
            searchFocused = false
            return
        }
        let newlySelectedID = newValue.flatMap { idx in
            idx < vm.sites.count ? vm.sites[idx].id : nil
        }
        // addSite가 방금 만든 사이트로의 전환이면 편집 상태·추적 id를 유지한다.
        if let pendingID = pendingNewSiteID, pendingID == newlySelectedID {
            searchFocused = false
            return
        }
        isAddingNew = false
        searchFocused = false
        // 이름을 정하지 않은 채 벗어난 새 사이트는 폐기한다.
        if oldValue != newValue, let pendingID = pendingNewSiteID,
            let pendingIdx = vm.sites.firstIndex(where: { $0.id == pendingID }),
            vm.sites[pendingIdx].name == Defaults.newSiteName
        {
            pendingNewSiteID = nil
            vm.sites.remove(at: pendingIdx)
            selectedIndex = newlySelectedID.flatMap { id in
                vm.sites.firstIndex(where: { $0.id == id })
            }
            return
        }
        pendingNewSiteID = nil
        save()
    }

    private func handleConfigDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url, url.pathExtension == "json" else { return }
            DispatchQueue.main.async {
                SettingsConfigTransfer.importFromURL(
                    url, vm: self.vm, onSuccess: handleSuccessfulImport)
            }
        }
        return true
    }

    private func openQA() {
        (NSApp.delegate as? AppDelegate)?.openQA()
    }

    private func openQAFromGuide() {
        showGuide = false
        DispatchQueue.main.async {
            (NSApp.delegate as? AppDelegate)?.openQA()
        }
    }

    private func focusSection(_ type: LaunchType) {
        // 섹션을 고르면 항목 선택은 해제한다. 한 번에 하나만 강조되어 + 대상이 명확하다.
        focusedLaunchType = type
        isLayoutsFocused = false
        selectedLayoutID = nil
        selectedTab = .launchables
        selectedIndex = nil
    }

    private func selectSite(_ index: Int) {
        selectedIndex = index
        selectedTab = .launchables
    }

    /// launcher 추가. type을 주면 그 섹션에, 없으면 현재 선택된 사이트의 타입을 물려받는다.
    private func addSite(type explicitType: LaunchType? = nil) {
        selectedTab = .launchables
        // Layouts 섹션이 대상이면 "+"·⌘N은 새 Layout을 캡처한다.
        if explicitType == nil, isLayoutsFocused {
            layoutActions.capture()
            return
        }
        // 이름을 정하지 않은 직전 placeholder가 남아 있으면 먼저 폐기해 중복 누적을 막는다.
        if let pendingID = pendingNewSiteID,
            let pendingIdx = vm.sites.firstIndex(where: { $0.id == pendingID }),
            vm.sites[pendingIdx].name == Defaults.newSiteName
        {
            vm.sites.remove(at: pendingIdx)
        }
        // 명시한 타입(빈 섹션의 Add 행)이 없으면 사이드바에서 고른 섹션에 만든다.
        let type = explicitType ?? focusedLaunchType
        focusedLaunchType = type
        guard SiteCountLimitPolicy.canAdd(type, to: vm.sites) else {
            LauncherUtils.showAlert(
                message: "Launch type limit reached",
                info:
                    "Only \(SiteCountLimitPolicy.limit(for: type)) \(typeSectionTitle(type)) "
                    + "launchables are allowed. Remove one before adding another.")
            return
        }
        let recommendation = InitialWindowSizeRecommendations.recommendation(for: type)
        let defaultSize = windowSize(for: recommendation, on: builtInScreen ?? cursorScreen)
        let newSite = Site(
            name: Defaults.newSiteName, url: type == .url ? "https://" : "",
            width: defaultSize.width, height: defaultSize.height,
            windowSizePreset: recommendation.sizePresetID,
            launchType: type)
        vm.sites.append(newSite)
        pendingNewSiteID = newSite.id
        isAddingNew = true
        selectedIndex = vm.sites.count - 1
    }

    /// 사이드바에서 Layout을 고른다. 사이트 선택은 풀고(편집 중인 값은 handleSelectionChange가 저장)
    /// Layouts 섹션을 "+"의 대상으로 둔다.
    private func selectLayout(_ id: UUID) {
        selectedTab = .launchables
        selectedIndex = nil
        isLayoutsFocused = true
        selectedLayoutID = id
    }

    private func removeSite() {
        guard let idx = selectedIndex, idx < vm.sites.count else { return }
        pendingNewSiteID = nil
        vm.sites.remove(at: idx)
        selectedIndex = vm.sites.isEmpty ? nil : min(idx, vm.sites.count - 1)
        save()
    }

    private func moveSiteUp() {
        guard let idx = selectedIndex else { return }
        let siblings = sameTypeIndices()
        guard let pos = siblings.firstIndex(of: idx), pos > 0 else { return }
        let prev = siblings[pos - 1]
        vm.sites.swapAt(idx, prev)
        selectedIndex = prev
        save()
    }

    private func moveSiteDown() {
        guard let idx = selectedIndex else { return }
        let siblings = sameTypeIndices()
        guard let pos = siblings.firstIndex(of: idx), pos < siblings.count - 1 else { return }
        let next = siblings[pos + 1]
        vm.sites.swapAt(idx, next)
        selectedIndex = next
        save()
    }

    /// 선택된 사이트와 같은 타입인 사이트들의 배열 인덱스 (사이드바 그룹 표시 순서와 일치)
    private func sameTypeIndices() -> [Int] {
        guard let idx = selectedIndex, idx < vm.sites.count else { return [] }
        let type = vm.sites[idx].launchType
        return vm.sites.indices.filter { vm.sites[$0].launchType == type }
    }

    private var canMoveUp: Bool {
        guard let idx = selectedIndex else { return false }
        let siblings = sameTypeIndices()
        guard let pos = siblings.firstIndex(of: idx) else { return false }
        return pos > 0
    }

    private var canMoveDown: Bool {
        guard let idx = selectedIndex else { return false }
        let siblings = sameTypeIndices()
        guard let pos = siblings.firstIndex(of: idx) else { return false }
        return pos < siblings.count - 1
    }

    private func typeSectionTitle(_ type: LaunchType) -> String {
        switch type {
        case .url: return "URL"
        case .app: return "App"
        case .finder: return "Finder"
        }
    }

    private func sidebarIcon(for site: Site) -> String {
        switch site.launchType {
        case .url:
            return site.displayName == nil ? "display.2" : "display"
        case .app:
            return "app.fill"
        case .finder:
            return "folder.fill"
        }
    }

    @State private var emptyFieldAlert = false
    @State private var emptyFieldMessage = ""

    private func handleSuccessfulImport() {
        pendingNewSiteID = nil
        isAddingNew = false

        let validSelection: Int?
        if vm.sites.isEmpty {
            validSelection = nil
        } else if let selectedIndex, vm.sites.indices.contains(selectedIndex) {
            validSelection = selectedIndex
        } else {
            validSelection = 0
        }

        if selectedIndex != validSelection {
            suppressNextSelectionSave = true
            selectedIndex = validSelection
        }
    }

    @discardableResult
    private func save(showAlerts: Bool = false) -> Bool {
        vm.cancelPendingSave()
        // Full config validation across ALL sites (not just selected)
        let config = Config(
            showGuideWindow: vm.showGuideWindow,
            launchAtLogin: vm.launchAtLogin,
            optionShortcutsEnabled: vm.optionShortcutsEnabled,
            statusBarIcon: vm.statusBarIcon,
            hiddenMenuLaunchTypes: vm.hiddenMenuLaunchTypes,
            notchLauncherEnabled: vm.notchLauncherEnabled,
            notchQuickNoteShortcut: vm.notchQuickNoteShortcut,
            coverScreensShortcut: vm.coverScreensShortcut,
            sites: vm.sites)
        let result = validateConfig(config)

        // For auto-saves (not user-triggered), silently skip if invalid
        if !result.isValid && !showAlerts {
            return false
        }

        // For manual saves, show validation errors
        if !result.isValid {
            let errorMessages = result.errors.map { issue in
                let siteName =
                    issue.siteIndex < vm.sites.count ? vm.sites[issue.siteIndex].name : "?"
                return "• \(siteName): \(issue.message)"
            }.joined(separator: "\n")
            emptyFieldMessage = errorMessages
            emptyFieldAlert = true
            return false
        }

        // Show warnings (non-blocking) only on manual save
        if showAlerts && !result.warnings.isEmpty {
            let warningMessages = result.warnings.map { issue in
                let siteName =
                    issue.siteIndex < vm.sites.count ? vm.sites[issue.siteIndex].name : "?"
                return "• \(siteName): \(issue.message)"
            }.joined(separator: "\n")
            let alert = NSAlert()
            alert.messageText = "Saved with warnings"
            alert.informativeText = warningMessages
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            // Save first, then show warning only if persistence succeeded.
            guard vm.persistCurrentState() else { return false }
            alert.runModal()
            return true
        }

        return vm.persistCurrentState()
    }

    /// 전역 설정(Guide Window, Login, Option Shortcuts, Status Bar Icon)만 저장.
    /// 편집 중인 사이트의 검증 상태와 무관하게 항상 저장되도록
    /// 사이트 목록은 마지막 저장 시점(originalSites)을 사용한다.
    private func saveGlobals() {
        guard !vm.isApplyingImportedConfig else { return }
        let saved =
            vm.onSave?(SettingsPayload(config: vm.globalsConfig)) ?? true
        if saved {
            // 사이트 draft는 그대로 두고 General/Notch baseline만 저장 상태로 맞춘다.
            vm.markGlobalsSaved()
        }
    }

    private func reportBug() {
        if let delegate = NSApp.delegate as? AppDelegate {
            delegate.reportBug()
        }
    }

    private func restartApp() {
        if let delegate = NSApp.delegate as? AppDelegate {
            delegate.restartApp()
        }
    }

    private func uninstallApp() {
        if let delegate = NSApp.delegate as? AppDelegate {
            delegate.uninstallApp()
        }
    }
}
