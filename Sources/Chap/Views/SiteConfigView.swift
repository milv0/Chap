import Cocoa
import SwiftUI
import UniformTypeIdentifiers

struct SiteConfigView: View {
    @Binding var site: Site
    @Binding var isEditing: Bool
    @State private var sizeSelection = 0
    @State private var suppressOnChange = false
    var onSave: (() -> Void)?

    private let sizeOptions = [
        "Custom", "Tiny (400x200)", "Mini (600x300)", "Medium (800x500)", "Large (1000x700)",
        "XL (1200x800)", "Wide (1000x400)", "Tall (500x800)", "Full (1400x900)",
    ]
    private let sizes: [(Int, Int)] = [
        (400, 200), (600, 300), (800, 500), (1000, 700), (1200, 800), (1000, 400), (500, 800),
        (1400, 900),
    ]

    var body: some View {
        ScrollView {
            CardSection {
                VStack(alignment: .leading, spacing: DS.spacing) {
                    InputField(label: "Name", text: $site.name, placeholder: "Site name")

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Type")
                            .font(DS.captionFont)
                            .foregroundColor(DS.textSecondary)
                        PillPicker(selection: $site.launchType)
                    }

                    switch site.launchType {
                    case .url:
                        urlFields
                    case .app:
                        appFields
                    case .finder:
                        finderFields
                    case .shell:
                        shellFields
                    }
                }
            }
            .padding(.horizontal, DS.padding)
            .padding(.top, DS.paddingSmall)
            .padding(.bottom, DS.padding)
        }
        .disabled(!isEditing)
        .onAppear { detectSizePreset() }
    }

    // MARK: - URL Fields

    private var urlFields: some View {
        Group {
            InputField(label: "URL", text: $site.url, placeholder: "https://")
            windowFields
        }
    }

    // MARK: - App Fields

    private var appFields: some View {
        Group {
            VStack(alignment: .leading, spacing: 6) {
                Text("App")
                    .font(DS.captionFont)
                    .foregroundColor(DS.textSecondary)
                HStack(spacing: 8) {
                    TextField(
                        "/Applications/...",
                        text: Binding(
                            get: { site.appPath ?? "" },
                            set: { site.appPath = $0 }
                        )
                    )
                    .textFieldStyle(.plain)
                    .font(DS.bodyFont)
                    .padding(DS.paddingSmall)
                    .background(DS.surfaceBg)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(DS.border, lineWidth: 1)
                    )

                    Button(action: browseForApp) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 12))
                            .foregroundColor(DS.accent)
                            .padding(8)
                            .background(DS.accentSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            windowFields
        }
    }

    // MARK: - Window Fields

    private var windowFields: some View {
        HStack(alignment: .top, spacing: DS.spacing) {
            VStack(alignment: .leading, spacing: DS.paddingSmall) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Display")
                        .font(DS.captionFont)
                        .foregroundColor(DS.textSecondary)
                    Picker(
                        "",
                        selection: Binding(
                            get: { site.displayName ?? "Auto" },
                            set: { site.displayName = $0 == "Auto" ? nil : $0 }
                        )
                    ) {
                        Text("Auto (cursor screen)").tag("Auto")
                        ForEach(NSScreen.screens, id: \.localizedName) { screen in
                            Text(screen.localizedName).tag(screen.localizedName)
                        }
                    }
                    .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Size Preset")
                        .font(DS.captionFont)
                        .foregroundColor(DS.textSecondary)
                    Picker("", selection: $sizeSelection) {
                        ForEach(0..<sizeOptions.count, id: \.self) { i in
                            Text(sizeOptions[i]).tag(i)
                        }
                    }
                    .labelsHidden()
                    .onChange(of: sizeSelection) { _, _ in
                        if !suppressOnChange { DispatchQueue.main.async { applySize() } }
                    }
                }

                HStack(spacing: DS.paddingSmall) {
                    InputField(
                        label: "Width",
                        text: Binding(
                            get: { "\(site.width)" },
                            set: { site.width = max(100, Int($0) ?? site.width) }),
                        placeholder: ""
                    )
                    .frame(width: 80)

                    InputField(
                        label: "Height",
                        text: Binding(
                            get: { "\(site.height)" },
                            set: { site.height = max(100, Int($0) ?? site.height) }),
                        placeholder: ""
                    )
                    .frame(width: 80)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                Text("Display Preview")
                    .font(DS.captionFont)
                    .foregroundColor(DS.textSecondary)
                MinimapSwiftUI(
                    width: site.width, height: site.height, displayName: site.displayName
                )
                .frame(maxWidth: .infinity, minHeight: 100)
                .id("\(site.width)-\(site.height)")
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Finder Fields

    private var finderFields: some View {
        Group {
            InputField(
                label: "Folder",
                text: Binding(
                    get: { site.folderPath ?? "" },
                    set: { site.folderPath = $0 }
                ),
                placeholder: "~/Documents"
            )
            windowFields
        }
    }

    // MARK: - Shell Fields

    private var shellFields: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Script")
                .font(DS.captionFont)
                .foregroundColor(DS.textSecondary)
            TextEditor(
                text: Binding(
                    get: { site.script ?? "" },
                    set: { site.script = $0 }
                )
            )
            .font(DS.monoFont)
            .frame(minHeight: 120)
            .padding(8)
            .background(DS.surfaceBg)
            .clipShape(RoundedRectangle(cornerRadius: DS.radiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: DS.radiusSmall)
                    .stroke(DS.border, lineWidth: 1)
            )
        }
    }

    // MARK: - Actions

    private func browseForApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        site.appPath = url.path
        if site.name == "New Launchable" || site.name.isEmpty {
            site.name = url.deletingPathExtension().lastPathComponent
        }
    }

    private func detectSizePreset() {
        DispatchQueue.main.async {
            suppressOnChange = true
            var detectedSize = 0
            for (i, sz) in sizes.enumerated() {
                if site.width == sz.0 && site.height == sz.1 {
                    detectedSize = i + 1
                    break
                }
            }
            sizeSelection = detectedSize
            suppressOnChange = false
        }
    }

    private func applySize() {
        guard sizeSelection > 0 else { return }
        let (w, h) = sizes[sizeSelection - 1]
        DispatchQueue.main.async {
            site.width = w
            site.height = h
        }
    }
}
