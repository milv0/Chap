import Cocoa
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Welcome View

struct WelcomeView: View {
    var onOpenSettings: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var dontShowAgain = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("⚡")
                .font(.system(size: 50))

            Text("Welcome to QuickAccess")
                .font(.system(size: 24, weight: .bold))

            VStack(alignment: .leading, spacing: 12) {
                GuideRow(icon: "plus.circle", text: "Add sites in Settings (Name + URL)")
                GuideRow(icon: "arrow.up.left.and.arrow.down.right", text: "Set window size, then click ⊹ Center")
                GuideRow(icon: "rectangle.grid.2x2", text: "Use Layout/Size presets for quick setup")
                GuideRow(icon: "cursorarrow.click.2", text: "Click a site from the menubar to launch")
                GuideRow(icon: "keyboard", text: "⌥Q opens menu, ⌥1~9 launches sites directly")
                GuideRow(icon: "checkmark.shield", text: "Allow Accessibility for keyboard shortcuts")
            }
            .padding(.horizontal, 24)

            Text("⚠️ First launch may not resize the window.\nJust re-open the site and it will work from then on.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()

            Toggle("Don't show this again", isOn: $dontShowAgain)
                .toggleStyle(.checkbox)
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Button(action: {
                if dontShowAgain {
                    UserDefaults.standard.set(true, forKey: "guideDisabled")
                }
                dismiss()
                onOpenSettings()
            }) {
                Text("Open Settings")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 234/255, green: 88/255, blue: 12/255))
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .frame(width: 500, height: 440)
    }
}

struct GuideRow: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundColor(Color(red: 234/255, green: 88/255, blue: 12/255))
            Text(text)
                .font(.system(size: 13))
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var vm: SettingsViewModel
    @State private var selectedIndex: Int? = nil
    @State private var showDeleteAlert = false
    @State private var showGuide = false

    var body: some View {
        HSplitView {
            VStack(spacing: 8) {
                List(selection: $selectedIndex) {
                    ForEach(vm.sites.indices, id: \.self) { i in
                        HStack(spacing: 4) {
                            Image(systemName: sidebarIcon(for: vm.sites[i]))
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Text(vm.sites[i].name)
                        }
                        .tag(i)
                    }
                    .onMove { from, to in
                        vm.sites.move(fromOffsets: from, toOffset: to)
                    }
                }
                .listStyle(.bordered)
                .frame(minWidth: 160)

                HStack(spacing: 4) {
                    Button("Add") { addSite() }
                    Button("Remove") { showDeleteAlert = true }
                        .disabled(selectedIndex == nil)
                }
                HStack(spacing: 4) {
                    Button("↑") { moveSiteUp() }
                        .disabled(selectedIndex == nil || selectedIndex == 0)
                    Button("↓") { moveSiteDown() }
                        .disabled(selectedIndex == nil || selectedIndex == vm.sites.count - 1)
                }
                .padding(.bottom, 8)
            }
            .frame(width: 180)

            VStack(alignment: .leading, spacing: 0) {
                if let idx = selectedIndex, idx < vm.sites.count {
                    SiteConfigView(site: $vm.sites[idx])
                } else {
                    Spacer()
                    Text("Select a site to configure")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                    Spacer()
                }

                Divider().padding(.vertical, 8)

                HStack {
                    Toggle("Run in Background", isOn: $vm.runInBackground)
                        .toggleStyle(.checkbox)
                        .font(.system(size: 11))

                    Spacer()

                    Button("?") { showGuide = true }
                        .font(.system(size: 11, weight: .bold))
                        .help("User Guide")
                    Button("Import") { importConfig() }
                    Button("Export") { exportConfig() }
                    Button("Reload") { vm.onReload?() }

                    Button("Save") { save() }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(red: 234/255, green: 88/255, blue: 12/255))
                        .disabled(!vm.hasChanges)
                        .keyboardShortcut("s", modifiers: .command)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .alert("Delete site?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) { removeSite() }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let idx = selectedIndex, idx < vm.sites.count {
                Text("This will remove \"\(vm.sites[idx].name)\".")
            }
        }
        .sheet(isPresented: $showGuide) {
            VStack(spacing: 16) {
                Text("User Guide ⚡")
                    .font(.system(size: 18, weight: .bold))
                    .padding(.top, 20)
                VStack(alignment: .leading, spacing: 10) {
                    GuideRow(icon: "cursorarrow.click.2", text: "Click ⚡ in menubar → select a site")
                    GuideRow(icon: "plus.circle", text: "Settings → add sites (Name + URL)")
                    GuideRow(icon: "arrow.up.left.and.arrow.down.right", text: "Set Width/Height, click ⊹ Center")
                    GuideRow(icon: "rectangle.grid.2x2", text: "Use Layout/Size presets")
                    GuideRow(icon: "square.and.arrow.up", text: "Import/Export to share settings")
                    GuideRow(icon: "power", text: "Launch at Login for auto-start")
                    GuideRow(icon: "display", text: "Always Center keeps windows centered")
                    GuideRow(icon: "keyboard", text: "⌥Q opens menu, ⌥1~9 launches sites")
                    GuideRow(icon: "checkmark.shield", text: "Allow Accessibility for shortcuts")
                }
                .padding(.horizontal, 24)
                Spacer()
                Button("Close") { showGuide = false }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 234/255, green: 88/255, blue: 12/255))
                    .padding(.bottom, 20)
            }
            .frame(width: 360, height: 340)
        }
    }

    private func addSite() {
        vm.sites.append(Site(name: "New Site", url: "https://", width: Defaults.defaultWidth, height: Defaults.defaultHeight, x: Defaults.defaultX, y: Defaults.defaultY))
        selectedIndex = vm.sites.count - 1
    }

    private func removeSite() {
        guard let idx = selectedIndex, idx < vm.sites.count else { return }
        vm.sites.remove(at: idx)
        selectedIndex = vm.sites.isEmpty ? nil : min(idx, vm.sites.count - 1)
    }

    private func moveSiteUp() {
        guard let idx = selectedIndex, idx > 0 else { return }
        vm.sites.swapAt(idx, idx - 1)
        selectedIndex = idx - 1
    }

    private func moveSiteDown() {
        guard let idx = selectedIndex, idx < vm.sites.count - 1 else { return }
        vm.sites.swapAt(idx, idx + 1)
        selectedIndex = idx + 1
    }

    private func sidebarIcon(for site: Site) -> String {
        switch site.launchType {
        case .url:
            return site.displayName == nil ? "display.2" : "display"
        case .app:
            return "app.fill"
        case .shell:
            return "terminal.fill"
        }
    }

    private func save() {
        vm.onSave?(vm.sites, vm.runInBackground)
        vm.markSaved()
    }

    private func exportConfig() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "quickaccess.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let configPath = NSString(string: "~/.quickaccess.json").expandingTildeInPath
        try? FileManager.default.copyItem(at: URL(fileURLWithPath: configPath), to: url)
    }

    private func importConfig() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            let config = try JSONDecoder().decode(Config.self, from: data)
            let configPath = NSString(string: "~/.quickaccess.json").expandingTildeInPath
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
}

// MARK: - Site Configuration Panel

struct SiteConfigView: View {
    @Binding var site: Site
    @State private var sizeSelection = 0
    @State private var suppressOnChange = false

    private let sizeOptions = ["Custom", "Tiny (400×200)", "Mini (600×300)", "Medium (800×500)", "Large (1000×700)", "XL (1200×800)", "Wide (1000×400)", "Tall (500×800)", "Full (1400×900)"]
    private let sizes: [(Int, Int)] = [(400,200), (600,300), (800,500), (1000,700), (1200,800), (1000,400), (500,800), (1400,900)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LabeledField("Name") {
                    TextField("Site name", text: $site.name)
                        .textFieldStyle(.roundedBorder)
                }

                LabeledField("Type") {
                    Picker("", selection: $site.launchType) {
                        Text("URL").tag(LaunchType.url)
                        Text("App").tag(LaunchType.app)
                        Text("Shell").tag(LaunchType.shell)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Divider()

                switch site.launchType {
                case .url:
                    urlConfigSection
                case .app:
                    appConfigSection
                case .shell:
                    shellConfigSection
                }

                Spacer()
            }
            .padding(16)
        }
        .onAppear { detectSizePreset() }
    }

    private var urlConfigSection: some View {
        Group {
            LabeledField("URL") {
                TextField("https://", text: $site.url)
                    .textFieldStyle(.roundedBorder)
            }

            Divider()

            windowConfigSection
        }
    }

    private var appConfigSection: some View {
        Group {
            LabeledField("App") {
                HStack {
                    TextField("/Applications/...", text: Binding(
                        get: { site.appPath ?? "" },
                        set: { site.appPath = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    Button("Browse") { browseForApp() }
                }
            }

            Divider()

            windowConfigSection
        }
    }

    private var windowConfigSection: some View {
        Group {
            LabeledField("Display") {
                Picker("", selection: Binding(
                    get: { site.displayName ?? "Auto" },
                    set: { site.displayName = $0 == "Auto" ? nil : $0 }
                )) {
                    Text("Auto (cursor screen)").tag("Auto")
                    ForEach(NSScreen.screens, id: \.localizedName) { screen in
                        Text(screen.localizedName).tag(screen.localizedName)
                    }
                }
                .labelsHidden()
            }

            Divider()

            LabeledField("Size") {
                Picker("", selection: $sizeSelection) {
                    ForEach(0..<sizeOptions.count, id: \.self) { i in
                        Text(sizeOptions[i]).tag(i)
                    }
                }
                .labelsHidden()
                .onChange(of: sizeSelection) { _, _ in if !suppressOnChange { applySize() } }
            }

            HStack(spacing: 12) {
                LabeledField("Width") {
                    TextField("", text: Binding(get: { "\(site.width)" }, set: { site.width = max(100, Int($0) ?? site.width) }))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }
                LabeledField("Height") {
                    TextField("", text: Binding(get: { "\(site.height)" }, set: { site.height = max(100, Int($0) ?? site.height) }))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }
            }

            MinimapSwiftUI(width: site.width, height: site.height, displayName: site.displayName)
                .frame(height: 80)
                .frame(maxWidth: .infinity)
                .id("\(site.width)-\(site.height)")
        }
    }

    private var shellConfigSection: some View {
        Group {
            VStack(alignment: .leading, spacing: 8) {
                Text("Script")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                TextEditor(text: Binding(
                    get: { site.script ?? "" },
                    set: { site.script = $0 }
                ))
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 120)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.3)))
            }
        }
    }

    private func browseForApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        site.appPath = url.path
        if site.name == "New Site" || site.name.isEmpty {
            site.name = url.deletingPathExtension().lastPathComponent
        }
    }

    private func detectSizePreset() {
        suppressOnChange = true
        var detectedSize = 0
        for (i, sz) in sizes.enumerated() {
            if site.width == sz.0 && site.height == sz.1 { detectedSize = i + 1; break }
        }
        sizeSelection = detectedSize
        suppressOnChange = false
    }

    private func applySize() {
        guard sizeSelection > 0 else { return }
        let (w, h) = sizes[sizeSelection - 1]
        site.width = w
        site.height = h
    }
}

// MARK: - Helper Views

struct LabeledField<Content: View>: View {
    let label: String
    let content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        HStack {
            Text(label)
                .frame(width: 50, alignment: .trailing)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            content
        }
    }
}

struct MinimapSwiftUI: View {
    let width: Int
    let height: Int
    var displayName: String? = nil

    var body: some View {
        GeometryReader { geo in
            let screens = NSScreen.screens
            let allFrames = screens.map { $0.frame }
            let minX = allFrames.map { $0.minX }.min() ?? 0
            let minY = allFrames.map { $0.minY }.min() ?? 0
            let maxX = allFrames.map { $0.maxX }.max() ?? 1512
            let maxY = allFrames.map { $0.maxY }.max() ?? 982
            let totalW = maxX - minX
            let totalH = maxY - minY

            let scale = min(geo.size.width / totalW, geo.size.height / totalH)
            let mapW = totalW * scale
            let mapH = totalH * scale
            let offsetX = (geo.size.width - mapW) / 2
            let offsetY = (geo.size.height - mapH) / 2

            ZStack(alignment: .topLeading) {
                ForEach(0..<screens.count, id: \.self) { i in
                    let frame = screens[i].frame
                    let sx = (frame.origin.x - minX) * scale
                    let sy = (maxY - frame.origin.y - frame.height) * scale

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.windowBackgroundColor))
                        .frame(width: frame.width * scale, height: frame.height * scale)
                        .overlay(
                            VStack {
                                Text(screens[i].localizedName)
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary)
                            }
                        )
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(
                            displayName == nil || screens[i].localizedName == displayName ? Color.orange : Color.gray.opacity(0.3)
                        ))
                        .offset(x: offsetX + sx, y: offsetY + sy)
                }

                let targetScreen = displayName.flatMap { name in screens.first { $0.localizedName == name } }
                    ?? NSScreen.main ?? screens.first!
                let tFrame = targetScreen.frame
                let screenLocalX = (tFrame.origin.x - minX) * scale
                let screenLocalY = (maxY - tFrame.origin.y - tFrame.height) * scale

                let winX = screenLocalX + (tFrame.width * scale - CGFloat(width) * scale) / 2
                let winY = screenLocalY + (tFrame.height * scale - CGFloat(height) * scale) / 2

                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.orange.opacity(0.3))
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.orange))
                    .frame(width: CGFloat(width) * scale, height: CGFloat(height) * scale)
                    .offset(x: offsetX + winX, y: offsetY + winY)
            }
        }
    }
}
