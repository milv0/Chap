import Cocoa
import SwiftUI
import UniformTypeIdentifiers
import os

struct SettingsView: View {
    @ObservedObject var vm: SettingsViewModel
    @State private var selectedIndex: Int? = nil
    @State private var showDeleteAlert = false
    @State private var showGuide = false
    @State private var showPasteJSON = false
    @State private var pasteJSONText = ""
    @State private var dropTargeted = false
    @State private var isEditing = false
    @State private var isAddingNew = false
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            mainPanel
        }
        .frame(minWidth: 700, minHeight: 580)
        .background(DS.surfaceBg)
        .onChange(of: selectedIndex) { oldValue, newValue in
            isAddingNew = false
            isEditing = false
            searchFocused = false
            // 이름을 정하지 않은 채(기본 "New Launchable") 벗어난 새 사이트는 폐기 —
            // 미완성 placeholder가 설정 파일/메뉴에 새어 들어가는 것을 방지
            if let old = oldValue, old != newValue, old < vm.sites.count,
                vm.sites[old].name == Defaults.newSiteName
            {
                let target = newValue.flatMap { idx in
                    idx < vm.sites.count ? vm.sites[idx] : nil
                }
                vm.sites.remove(at: old)
                // 클릭한 사이트가 제거로 인덱스가 밀렸을 수 있으므로 다시 찾음
                selectedIndex = target.flatMap { vm.sites.firstIndex(of: $0) }
                return
            }
            // 선택 변경 시 자동 저장
            save()
        }
        .background(siteSelectionShortcuts)
        .alert("Delete site?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) { removeSite() }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let idx = selectedIndex, idx < vm.sites.count {
                Text("This will remove \"\(vm.sites[idx].name)\".")
            }
        }
        .sheet(isPresented: $showGuide) { guideSheet }
        .alert("Shortcut Conflict", isPresented: $duplicateShortcutAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("⌥\(duplicateShortcutChar) is already assigned to another site.")
        }
        .alert("Duplicate Site", isPresented: $duplicateSiteAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(duplicateSiteMessage)
        }
        .alert("Required Field", isPresented: $emptyFieldAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(emptyFieldMessage)
        }
        .sheet(isPresented: $showPasteJSON) { pasteJSONSheet }
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url = url, url.pathExtension == "json" else { return }
                DispatchQueue.main.async {
                    self.importFromURL(url)
                }
            }
            return true
        }
        .overlay(
            dropTargeted
                ? RoundedRectangle(cornerRadius: DS.radius)
                    .stroke(DS.accent, lineWidth: 3)
                    .padding(4)
                : nil
        )
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
                        if !indices.isEmpty {
                            Text(typeSectionTitle(type))
                                .font(DS.captionFont)
                                .foregroundColor(DS.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.top, 8)
                            ForEach(indices, id: \.self) { i in
                                SidebarItem(
                                    icon: sidebarIcon(for: vm.sites[i]),
                                    name: vm.sites[i].name,
                                    badge: vm.sites[i].shortcut.map { "⌥ \($0)" },
                                    isSelected: selectedIndex == i
                                )
                                .contentShape(Rectangle())
                                .onTapGesture { selectedIndex = i }
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
                                        onDrop: { save() }
                                    ))
                            }
                        }
                    }
                }
                .padding(DS.spacingSmall)
            }

            Divider()

            HStack(spacing: 4) {
                ToolbarIconButton(
                    icon: "plus", color: DS.textSecondary, action: addSite)
                ToolbarIconButton(
                    icon: "minus", color: DS.danger,
                    action: { showDeleteAlert = true },
                    disabled: selectedIndex == nil)

                Spacer()

                ToolbarIconButton(
                    icon: "chevron.up", color: DS.textSecondary,
                    action: moveSiteUp,
                    disabled: !canMoveUp)
                ToolbarIconButton(
                    icon: "chevron.down", color: DS.textSecondary,
                    action: moveSiteDown,
                    disabled: !canMoveDown)
            }
            .padding(.horizontal, 8)
            .frame(height: 40)
        }
        .frame(width: 200)
    }

    // MARK: - Main Panel

    private var mainPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let idx = selectedIndex, idx < vm.sites.count {
                SiteConfigView(
                    site: $vm.sites[idx], isEditing: $isEditing, isNew: isAddingNew,
                    onSave: { save() }
                )
                .onTapGesture { isEditing = true }
                .onChange(of: vm.sites) { _, _ in
                    if isEditing { save() }
                }
            } else {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 28))
                        .foregroundColor(DS.textTertiary)
                    Text("Select a site to configure")
                        .font(DS.bodyFont)
                        .foregroundColor(DS.textSecondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            }

            Divider()

            bottomBar
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: DS.spacingSmall) {
            Toggle("Guide Window", isOn: $vm.showGuideWindow)
                .toggleStyle(.switch)
                .controlSize(.small)
                .font(DS.captionFont)
                .help("Show window position guide while launching")
                .onChange(of: vm.showGuideWindow) { _, _ in saveGlobals() }

            Toggle("Login", isOn: $vm.launchAtLogin)
                .toggleStyle(.switch)
                .controlSize(.small)
                .font(DS.captionFont)
                .help("Open automatically when you log in")
                .onChange(of: vm.launchAtLogin) { _, _ in saveGlobals() }

            Spacer()

            Button(action: { showGuide = true }) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 13))
                    .foregroundColor(DS.textSecondary)
            }
            .buttonStyle(.plain)
            .help("User Guide")
            .keyboardShortcut("/", modifiers: .command)

            Menu {
                Button("Import from File...") { importConfig() }
                Button("Paste JSON...") {
                    pasteJSONText = ""
                    showPasteJSON = true
                }
                Divider()
                Button("Export...") { exportConfig() }
                Divider()
                Button("Restart App") { restartApp() }
                Button("Uninstall...") { uninstallApp() }
            } label: {
                Image(systemName: "folder")
                    .font(.system(size: 13))
                    .foregroundColor(DS.textSecondary)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 24)

            if isEditing {
                Text("Editing")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DS.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
            }

            Button("") {
                save(showAlerts: true)
                isEditing = false
            }
            .keyboardShortcut(.return, modifiers: [])
            .frame(width: 0, height: 0)
            .opacity(0)

            Button("") {
                save(showAlerts: true)
            }
            .keyboardShortcut("s", modifiers: .command)
            .frame(width: 0, height: 0)
            .opacity(0)
        }
        .padding(.horizontal, DS.paddingSmall)
        .frame(height: 40)
    }

    // MARK: - Guide Sheet

    private var guideSheet: some View {
        VStack(spacing: DS.spacing) {
            Spacer()

            Text("User Guide")
                .font(DS.titleFont)
                .foregroundColor(DS.textPrimary)

            VStack(spacing: 10) {
                CardSection {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("App Usage  ⌥")
                            .font(DS.headlineFont)
                            .foregroundColor(DS.textPrimary)
                        guideRow(icon: "cursorarrow.click.2", text: "Click menubar icon to select")
                        guideRow(
                            icon: "keyboard", text: "⌥. menu, ⌥(custom key) launch, ⌥, settings")
                        guideRow(
                            icon: "checkmark.shield", text: "Allow Accessibility for shortcuts")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                CardSection {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Settings  ⌘")
                            .font(DS.headlineFont)
                            .foregroundColor(DS.textPrimary)
                        guideRow(icon: "plus.circle", text: "Add sites (Name + URL + Shortcut)")
                        guideRow(icon: "display", text: "Choose display + size — always centered")
                        guideRow(
                            icon: "cursorarrow.click",
                            text: "Click to edit, Enter or ⌘S to save, ⌘N to add")
                        guideRow(icon: "square.and.arrow.down", text: "Drag .json to import")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            PrimaryButton(title: "Close") { showGuide = false }
                .padding(.horizontal, 40)
                .padding(.bottom, 24)
        }
        .frame(width: 440, height: 540)
        .background(DS.surfaceBg)
    }

    // MARK: - Paste JSON Sheet

    private var pasteJSONSheet: some View {
        VStack(spacing: DS.spacing) {
            Text("Paste JSON")
                .font(DS.headlineFont)
                .foregroundColor(DS.textPrimary)
                .padding(.top, DS.padding)

            TextEditor(text: $pasteJSONText)
                .font(DS.monoFont)
                .frame(minHeight: 200)
                .padding(8)
                .background(DS.surfaceBg)
                .clipShape(RoundedRectangle(cornerRadius: DS.radiusSmall))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.radiusSmall)
                        .stroke(DS.border, lineWidth: 1)
                )
                .padding(.horizontal, DS.padding)

            HStack {
                Button("Cancel") { showPasteJSON = false }
                    .buttonStyle(.plain)
                    .foregroundColor(DS.textSecondary)
                Spacer()
                PrimaryButton(title: "Apply") {
                    applyJSONString(pasteJSONText)
                    showPasteJSON = false
                }
                .frame(width: 100)
                .opacity(
                    pasteJSONText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1
                )
                .disabled(pasteJSONText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, DS.padding)
            .padding(.bottom, DS.padding)
        }
        .frame(width: 500, height: 350)
        .background(DS.surfaceBg)
    }

    // MARK: - Keyboard Shortcuts

    @ViewBuilder
    private var siteSelectionShortcuts: some View {
        ForEach(0..<min(9, vm.sites.count), id: \.self) { i in
            Button("") { selectedIndex = i }
                .keyboardShortcut(KeyEquivalent(Character("\(i + 1)")), modifiers: .command)
                .frame(width: 0, height: 0)
                .opacity(0)
        }
        Button("") { moveSelection(by: -1) }
            .keyboardShortcut(.upArrow, modifiers: [])
            .frame(width: 0, height: 0)
            .opacity(0)

        Button("") { moveSelection(by: 1) }
            .keyboardShortcut(.downArrow, modifiers: [])
            .frame(width: 0, height: 0)
            .opacity(0)

        Button("") { addSite() }
            .keyboardShortcut("n", modifiers: .command)
            .frame(width: 0, height: 0)
            .opacity(0)
    }

    /// 사이드바에 표시되는 순서 (타입별 그룹) 기준으로 이동
    private func moveSelection(by offset: Int) {
        let displayOrder = LaunchType.allCases.flatMap { type in
            vm.sites.indices.filter { vm.sites[$0].launchType == type }
        }
        guard !displayOrder.isEmpty else { return }
        guard let current = selectedIndex,
            let pos = displayOrder.firstIndex(of: current)
        else {
            selectedIndex = displayOrder.first
            return
        }
        let newPos = pos + offset
        if newPos >= 0 && newPos < displayOrder.count {
            selectedIndex = displayOrder[newPos]
        }
    }

    // MARK: - Helpers

    private func guideRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(DS.accent)
                .frame(width: 16)
            Text(text)
                .font(DS.bodyFont)
                .foregroundColor(DS.textSecondary)
        }
    }

    private func addSite() {
        // 현재 선택된 사이트의 타입을 물려받아, 선택된 섹션(URL/App/Finder/Shell)에 추가
        let type: LaunchType = {
            if let idx = selectedIndex, idx < vm.sites.count {
                return vm.sites[idx].launchType
            }
            return .url
        }()
        vm.sites.append(
            Site(
                name: Defaults.newSiteName, url: type == .url ? "https://" : "",
                width: Defaults.defaultWidth, height: Defaults.defaultHeight,
                launchType: type))
        isAddingNew = true
        isEditing = true
        selectedIndex = vm.sites.count - 1
    }

    private func removeSite() {
        guard let idx = selectedIndex, idx < vm.sites.count else { return }
        vm.sites.remove(at: idx)
        selectedIndex = vm.sites.isEmpty ? nil : min(idx, vm.sites.count - 1)
        isEditing = false
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
        case .shell: return "Shell"
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
        case .shell:
            return "terminal.fill"
        }
    }

    @State private var duplicateShortcutAlert = false
    @State private var duplicateShortcutChar = ""
    @State private var duplicateSiteAlert = false
    @State private var duplicateSiteMessage = ""
    @State private var emptyFieldAlert = false
    @State private var emptyFieldMessage = ""

    private func save(showAlerts: Bool = false) {
        if let idx = selectedIndex, idx < vm.sites.count {
            let site = vm.sites[idx]

            // 필수 필드 체크 — alert는 수동 저장 시에만
            let missingField = checkRequiredFields(site: site)
            if let field = missingField {
                if showAlerts {
                    emptyFieldMessage = "\(field) is required for \(site.launchType.rawValue) type."
                    emptyFieldAlert = true
                }
                return
            }

            // 단축키 중복 체크
            if let key = site.shortcut?.uppercased(), !key.isEmpty {
                if vm.sites.enumerated().contains(where: {
                    $0.offset != idx && $0.element.shortcut?.uppercased() == key
                }) {
                    duplicateShortcutChar = key
                    duplicateShortcutAlert = true
                    vm.sites[idx].shortcut = nil
                    return
                }
            }

            // 사이트 중복 체크 (동일 URL, 앱, 폴더)
            let duplicateName = checkDuplicateSite(index: idx, site: site)
            if let name = duplicateName {
                duplicateSiteMessage = "\"\(site.name)\" is duplicated with \"\(name)\"."
                duplicateSiteAlert = true
                return
            }
        }
        let saved =
            vm.onSave?(
                SettingsPayload(
                    sites: vm.sites, showGuideWindow: vm.showGuideWindow,
                    launchAtLogin: vm.launchAtLogin)) ?? true
        if saved {
            vm.markSaved()
        }
    }

    /// 전역 토글(Guide Window, Login)만 저장.
    /// 편집 중인 사이트의 검증 상태와 무관하게 항상 저장되도록
    /// 사이트 목록은 마지막 저장 시점(originalSites)을 사용한다.
    private func saveGlobals() {
        let saved =
            vm.onSave?(
                SettingsPayload(
                    sites: vm.originalSites, showGuideWindow: vm.showGuideWindow,
                    launchAtLogin: vm.launchAtLogin)) ?? true
        if saved {
            vm.originalGuide = vm.showGuideWindow
            vm.originalLogin = vm.launchAtLogin
        }
    }

    private func checkDuplicateSite(index: Int, site: Site) -> String? {
        for (i, other) in vm.sites.enumerated() where i != index {
            guard other.launchType == site.launchType else { continue }
            switch site.launchType {
            case .url:
                if !site.url.isEmpty && site.url == other.url { return other.name }
            case .app:
                if let path = site.appPath, !path.isEmpty, path == other.appPath {
                    return other.name
                }
            case .finder:
                if let path = site.folderPath, !path.isEmpty, path == other.folderPath {
                    return other.name
                }
            case .shell:
                break
            }
        }
        return nil
    }

    private func checkRequiredFields(site: Site) -> String? {
        if site.name.isEmpty || site.name == Defaults.newSiteName { return "Name" }
        switch site.launchType {
        case .url:
            if site.url.isEmpty || site.url == "https://" { return "URL" }
        case .app:
            if site.appPath?.isEmpty ?? true { return "App path" }
        case .finder:
            if site.folderPath?.isEmpty ?? true { return "Folder path" }
        case .shell:
            if site.script?.isEmpty ?? true { return "Script" }
        }
        return nil
    }

    private func exportConfig() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "chap.json"
        panel.directoryURL =
            FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        guard panel.runModal() == .OK, let url = panel.url else { return }

        // 디스크 파일이 아닌 현재 편집 상태를 내보냄 (저장 안 된 변경분 포함)
        let config = Config(
            showGuideWindow: vm.showGuideWindow, launchAtLogin: vm.launchAtLogin, sites: vm.sites)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        do {
            try encoder.encode(config).write(to: url, options: .atomic)
            Log.config.info("Config exported to \(url.path, privacy: .private)")
            let alert = NSAlert()
            alert.messageText = "Export successful"
            alert.informativeText = "Saved to \(url.path)"
            alert.alertStyle = .informational
            alert.runModal()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Export failed"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
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

    private func importConfig() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let data = try? Data(contentsOf: url) else {
            showImportError("Could not read file.")
            return
        }
        applyConfigData(data)
    }

    private func applyJSONString(_ jsonString: String) {
        guard let data = jsonString.data(using: .utf8) else { return }
        applyConfigData(data)
    }

    private func importFromURL(_ url: URL) {
        guard let data = try? Data(contentsOf: url) else {
            showImportError("Could not read file.")
            return
        }
        applyConfigData(data)
    }

    private func applyConfigData(_ data: Data) {
        do {
            let config = try JSONDecoder().decode(Config.self, from: data)
            let bakPath = Defaults.configPath + ".bak"
            try? FileManager.default.removeItem(atPath: bakPath)
            try? FileManager.default.copyItem(atPath: Defaults.configPath, toPath: bakPath)
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let cleanData = try encoder.encode(config)
            try cleanData.write(to: URL(fileURLWithPath: Defaults.configPath), options: .atomic)
            vm.sites = config.sites
            vm.showGuideWindow = config.showGuideWindow
            vm.launchAtLogin = config.launchAtLogin
            vm.markSaved()  // 방금 디스크에 반영했으므로 기준값 갱신 (닫을 때 오경보 방지)
            vm.onReload?()
            let alert = NSAlert()
            alert.messageText = "Import successful"
            alert.informativeText = "\(config.sites.count) site(s) loaded."
            alert.alertStyle = .informational
            alert.runModal()
        } catch {
            showImportError(error.localizedDescription)
        }
    }

    private func showImportError(_ detail: String) {
        let alert = NSAlert()
        alert.messageText = "Failed to import config."
        alert.informativeText = detail
        alert.alertStyle = .warning
        alert.runModal()
    }
}
