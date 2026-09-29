import Cocoa
import SwiftUI

/// Launch-type specific input fields extracted from SiteConfigView.
/// Renders URL, App, or Finder fields based on the current launchType.
struct SiteLaunchFields: View {
    @Binding var site: Site
    @Binding var isEditing: Bool
    let browseForApp: () -> Void
    let browseFolder: () -> Void

    var body: some View {
        switch site.launchType {
        case .url:
            urlFields
        case .app:
            appFields
        case .finder:
            finderFields
        }
    }

    // MARK: - URL Fields

    private var urlFields: some View {
        VStack(alignment: .leading, spacing: 10) {
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

            Divider()

            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "macwindow.on.rectangle")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(
                        site.reuseExistingWindow ? DS.accent : DS.textSecondary
                    )
                    .frame(width: 28, height: 28)
                    .background(
                        site.reuseExistingWindow
                            ? DS.accentSoft
                            : DS.border.opacity(0.18)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 7))

                Text("Reuse Existing URL Window")
                    .font(DS.bodyFont.weight(.medium))
                    .foregroundColor(DS.textPrimary)

                Spacer(minLength: 8)

                Toggle("Reuse Existing URL Window", isOn: $site.reuseExistingWindow)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .help(
                        "Reuse only the Chrome app window created by this launchable."
                    )
            }
            .opacity(isEditing ? 1 : 0.45)
        }
    }

    // MARK: - App Fields

    private var appFields: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Application")
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
                        .font(.system(size: 14))
                }
                .buttonStyle(.bordered)
                .frame(height: 30)
            }
        }
    }

    // MARK: - Finder Fields

    private var finderFields: some View {
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
    }
}
