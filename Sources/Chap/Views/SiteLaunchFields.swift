import Cocoa
import SwiftUI

struct ScriptEditorFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

/// Launch-type specific input fields extracted from SiteConfigView.
/// Renders URL, App, Finder, or Shell fields based on the current launchType.
struct SiteLaunchFields: View {
    @Binding var site: Site
    @Binding var isEditing: Bool
    /// Closure to present the window/display configuration section.
    /// Provided by the parent so that URL/App/Finder types can embed it.
    let windowFields: AnyView
    let browseForApp: () -> Void
    let browseFolder: () -> Void
    var scriptFocused: FocusState<Bool>.Binding

    var body: some View {
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

    // MARK: - URL Fields

    private var urlFields: some View {
        Group {
            InputField(
                label: "URL",
                text: Binding(
                    get: { site.url },
                    set: { newURL in
                        site.url = newURL
                        if site.name == Defaults.newSiteName || site.name.isEmpty,
                            let host = URL(string: newURL)?.host
                        {
                            site.name =
                                host.replacingOccurrences(of: "www.", with: "")
                                .components(separatedBy: ".").first?.capitalized ?? host
                        }
                    }
                ),
                placeholder: "https://"
            )
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
                            set: { newPath in
                                site.appPath = newPath
                                if !newPath.isEmpty {
                                    let appName = URL(fileURLWithPath: newPath)
                                        .deletingPathExtension().lastPathComponent
                                    if site.name == Defaults.newSiteName || site.name.isEmpty {
                                        site.name = appName
                                    }
                                }
                            }
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

    // MARK: - Finder Fields

    private var finderFields: some View {
        Group {
            HStack(alignment: .bottom) {
                InputField(
                    label: "Folder",
                    text: Binding(
                        get: { site.folderPath ?? "" },
                        set: { newPath in
                            site.folderPath = newPath
                            if site.name == Defaults.newSiteName || site.name.isEmpty,
                                !newPath.isEmpty
                            {
                                site.name = URL(fileURLWithPath: newPath).lastPathComponent
                            }
                        }
                    ),
                    placeholder: "~/Documents"
                )
                Button(action: browseFolder) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 14))
                }
                .buttonStyle(.bordered)
                .frame(height: 30)
            }
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
            .focused(scriptFocused)
            .frame(minHeight: 120)
            .padding(8)
            .background(DS.surfaceBg)
            .clipShape(RoundedRectangle(cornerRadius: DS.radiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: DS.radiusSmall)
                    .stroke(DS.border, lineWidth: 1)
            )
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: ScriptEditorFramePreferenceKey.self,
                        value: proxy.frame(in: .named("SiteConfigForm"))
                    )
                }
            )
        }
    }
}
