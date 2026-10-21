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
        // Reuse 토글은 창 관련 설정이라 Window 묶음(SiteWindowConfigView)에 있다.
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
                .padding(.horizontal, DS.fieldPaddingH)
                .padding(.vertical, DS.fieldPaddingV)
                .background(DS.surfaceBg)
                .clipShape(RoundedRectangle(cornerRadius: DS.fieldRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.fieldRadius)
                        .stroke(DS.border, lineWidth: 1)
                )
                Button(action: browseForApp) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 14))
                }
                .buttonStyle(.bordered)
                .frame(height: 28)
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
