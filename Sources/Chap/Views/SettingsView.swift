import Cocoa
import SwiftUI
import UniformTypeIdentifiers

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

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            mainPanel
        }
        .frame(minWidth: 700, minHeight: 580)
        .background(DS.surfaceBg)
        .onChange(of: selectedIndex) { _, _ in
            isAddingNew = false
            isEditing = false
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
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(LaunchType.allCases, id: \.self) { type in
                        let indices = vm.sites.indices.filter { vm.sites[$0].launchType == type }
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
                                    subtitle: sidebarSubtitle(for: vm.sites[i]),
                                    badge: vm.sites[i].shortcut.map { "⌥\($0)" },
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
                    disabled: selectedIndex == nil || selectedIndex == 0)
                ToolbarIconButton(
                    icon: "chevron.down", color: DS.textSecondary,
                    action: moveSiteDown,
                    disabled: selectedIndex == nil || selectedIndex == vm.sites.count - 1)
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
                SiteConfigView(site: $vm.sites[idx], isEditing: $isEditing, onSave: { save() })
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
            Toggle("Guide", isOn: $vm.showGhostWindow)
                .toggleStyle(.switch)
                .controlSize(.small)
                .font(DS.captionFont)
                .help("Show window position guide while launching")
                .onChange(of: vm.showGhostWindow) { _, _ in save() }

            Toggle("Login", isOn: $vm.launchAtLogin)
                .toggleStyle(.switch)
                .controlSize(.small)
                .font(DS.captionFont)
                .help("Open automatically when you log in")
                .onChange(of: vm.launchAtLogin) { _, _ in save() }

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
                save()
                isEditing = false
            }
            .keyboardShortcut(.return, modifiers: [])
            .frame(width: 0, height: 0)
            .opacity(0)

            Button("") {
                save()
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
                        guideRow(icon: "keyboard", text: "⌥Q menu, ⌥(custom key) launch, ⌥, settings")
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
                        guideRow(icon: "cursorarrow.click", text: "Click to edit, Enter or ⌘S to save")
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
        .frame(width: 400, height: 460)
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
        vm.sites.append(
            Site(
                name: "New Launchable", url: "https://", width: Defaults.defaultWidth,
                height: Defaults.defaultHeight, x: Defaults.defaultX, y: Defaults.defaultY))
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
        guard let idx = selectedIndex, idx > 0 else { return }
        vm.sites.swapAt(idx, idx - 1)
        selectedIndex = idx - 1
        save()
    }

    private func moveSiteDown() {
        guard let idx = selectedIndex, idx < vm.sites.count - 1 else { return }
        vm.sites.swapAt(idx, idx + 1)
        selectedIndex = idx + 1
        save()
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

    private func sidebarSubtitle(for site: Site) -> String? {
        switch site.launchType {
        case .url:
            let urlStr = site.url
            if let host = URL(string: urlStr)?.host {
                return host
            }
            return nil
        case .app:
            if let path = site.appPath {
                return URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
            }
            return nil
        case .finder:
            return site.folderPath
        case .shell:
            return "script"
        }
    }

    @State private var duplicateShortcutAlert = false
    @State private var duplicateShortcutChar = ""

    private func save() {
        // 단축키 중복 체크
        if let idx = selectedIndex, idx < vm.sites.count,
           let key = vm.sites[idx].shortcut?.uppercased(),
           !key.isEmpty {
            let conflict = vm.sites.enumerated().first(where: {
                $0.offset != idx && $0.element.shortcut?.uppercased() == key
            })
            if let conflict = conflict {
                duplicateShortcutChar = key
                duplicateShortcutAlert = true
                // 현재 사이트의 shortcut 제거
                vm.sites[idx].shortcut = nil
                return
            }
        }
        vm.onSave?(SettingsPayload(sites: vm.sites, runInBackground: vm.runInBackground, showGhostWindow: vm.showGhostWindow, launchAtLogin: vm.launchAtLogin))
        vm.markSaved()
    }

    private func exportConfig() {
        let downloadsPath = NSString(string: "~/Downloads/chap.json").expandingTildeInPath
        try? FileManager.default.removeItem(atPath: downloadsPath)
        try? FileManager.default.copyItem(atPath: Defaults.configPath, toPath: downloadsPath)
        NSLog("[Chap] Config exported to %@", downloadsPath)
        let alert = NSAlert()
        alert.messageText = "Export successful"
        alert.informativeText = "Saved to ~/Downloads/chap.json"
        alert.alertStyle = .informational
        alert.runModal()
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
            try data.write(to: URL(fileURLWithPath: Defaults.configPath), options: .atomic)
            vm.sites = config.sites
            vm.runInBackground = config.runInBackground
            vm.showGhostWindow = config.showGhostWindow
            vm.launchAtLogin = config.launchAtLogin
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
