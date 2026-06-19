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
        .frame(minWidth: 700, minHeight: 500)
        .background(DS.surfaceBg)
        .onChange(of: selectedIndex) { _, _ in
            if isAddingNew {
                isAddingNew = false
            } else {
                isEditing = false
            }
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
                    ForEach(vm.sites.indices, id: \.self) { i in
                        SidebarItem(
                            icon: sidebarIcon(for: vm.sites[i]),
                            name: vm.sites[i].name,
                            subtitle: sidebarSubtitle(for: vm.sites[i]),
                            badge: i < 9 ? "⌥\(i + 1)" : nil,
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
            Toggle("Background", isOn: $vm.runInBackground)
                .toggleStyle(.switch)
                .controlSize(.small)
                .font(DS.captionFont)

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
                Button(action: {
                    save()
                    isEditing = false
                }) {
                    Text("Save")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(DS.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            } else if selectedIndex != nil {
                Button(action: { isEditing = true }) {
                    Text("Edit")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DS.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(DS.border.opacity(0.3))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .keyboardShortcut("e", modifiers: .command)
            }

            Button("") {
                save()
                isEditing = false
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
                        guideRow(icon: "keyboard", text: "⌥Q menu, ⌥1~9 launch, ⌥, settings")
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
                        guideRow(icon: "plus.circle", text: "Add sites (Name + URL)")
                        guideRow(icon: "display", text: "Choose display + size — always centered")
                        guideRow(icon: "square.and.arrow.down", text: "Drag .json to import")
                        guideRow(icon: "keyboard", text: "⌘E edit, ⌘S save, ⌘1~9 select")
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

    private func save() {
        vm.onSave?(vm.sites, vm.runInBackground)
        vm.markSaved()
    }

    private func exportConfig() {
        let configPath = NSString(string: "~/.chap.json").expandingTildeInPath
        let downloadsPath = NSString(string: "~/Downloads/chap.json").expandingTildeInPath
        try? FileManager.default.removeItem(atPath: downloadsPath)
        try? FileManager.default.copyItem(atPath: configPath, toPath: downloadsPath)
        NSLog("[Chap] Config exported to %@", downloadsPath)
        let alert = NSAlert()
        alert.messageText = "Export successful"
        alert.informativeText = "Saved to ~/Downloads/chap.json"
        alert.alertStyle = .informational
        alert.runModal()
    }

    private func restartApp() {
        let url = URL(fileURLWithPath: Bundle.main.bundlePath)
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", url.path]
        try? task.run()
        NSApp.terminate(nil)
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
        do {
            let data = try Data(contentsOf: url)
            let config = try JSONDecoder().decode(Config.self, from: data)
            let configPath = NSString(string: "~/.chap.json").expandingTildeInPath
            try data.write(to: URL(fileURLWithPath: configPath), options: .atomic)
            vm.sites = config.sites
            vm.runInBackground = config.runInBackground
            vm.onReload?()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Failed to import config."
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    private func applyJSONString(_ jsonString: String) {
        guard let data = jsonString.data(using: .utf8) else { return }
        do {
            let config = try JSONDecoder().decode(Config.self, from: data)
            let configPath = NSString(string: "~/.chap.json").expandingTildeInPath
            try data.write(to: URL(fileURLWithPath: configPath), options: .atomic)
            vm.sites = config.sites
            vm.runInBackground = config.runInBackground
            vm.onReload?()
            let alert = NSAlert()
            alert.messageText = "Import successful"
            alert.informativeText = "\(config.sites.count) site(s) loaded."
            alert.alertStyle = .informational
            alert.runModal()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Invalid JSON."
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    private func importFromURL(_ url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let config = try JSONDecoder().decode(Config.self, from: data)
            let configPath = NSString(string: "~/.chap.json").expandingTildeInPath
            try data.write(to: URL(fileURLWithPath: configPath), options: .atomic)
            vm.sites = config.sites
            vm.runInBackground = config.runInBackground
            vm.onReload?()
            let alert = NSAlert()
            alert.messageText = "Import successful"
            alert.informativeText = "\(config.sites.count) site(s) loaded."
            alert.alertStyle = .informational
            alert.runModal()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Failed to import config."
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
}
