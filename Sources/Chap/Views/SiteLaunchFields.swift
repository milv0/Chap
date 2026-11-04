import Cocoa
import SwiftUI

/// Launch-type specific target field shown beside Name in the Launcher section.
/// Inline label + field so it reads on one baseline with the Name field.
struct SiteLaunchFields: View {
    @Binding var site: Site
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

    private var urlFields: some View {
        HStack(spacing: 8) {
            fieldLabel("URL")
            TextField(
                "https://",
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
                )
            )
            .labelsHidden()
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel("URL")
        }
    }

    private var appFields: some View {
        HStack(spacing: 8) {
            fieldLabel("App")
            TextField(
                "/Applications/…",
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
            .labelsHidden()
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel("Application")
            Button(action: browseForApp) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 14))
            }
            .buttonStyle(.bordered)
            .help("Choose application")
            .accessibilityLabel("Choose application")
        }
    }

    private var finderFields: some View {
        HStack(spacing: 8) {
            fieldLabel("Folder")
            TextField(
                "~/Documents",
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
                )
            )
            .labelsHidden()
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel("Folder")
            Button(action: browseFolder) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 14))
            }
            .buttonStyle(.bordered)
            .help("Choose folder")
            .accessibilityLabel("Choose folder")
        }
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .foregroundColor(DS.textSecondary)
            .fixedSize()
    }
}
