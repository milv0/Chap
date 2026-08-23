import Cocoa
import SwiftUI

struct ScriptEditorFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

final class UndoableScriptTextView: NSTextView {
    private let scriptUndoManager = UndoManager()

    static func makeEditable() -> UndoableScriptTextView {
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(
            size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)

        let textView = UndoableScriptTextView(frame: .zero, textContainer: textContainer)
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        return textView
    }

    override var undoManager: UndoManager? {
        scriptUndoManager
    }

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isControlZ =
            modifiers.contains(.control)
            && !modifiers.contains(.command)
            && !modifiers.contains(.option)
            && event.charactersIgnoringModifiers?.lowercased() == "z"

        guard isControlZ else {
            super.keyDown(with: event)
            return
        }

        if modifiers.contains(.shift) {
            undoManager?.redo()
        } else {
            undoManager?.undo()
        }
    }
}

struct ScriptTextEditor: NSViewRepresentable {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isFocused: isFocused)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = UndoableScriptTextView.makeEditable()
        textView.delegate = context.coordinator
        textView.string = text
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textColor = .labelColor
        textView.drawsBackground = false
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude)

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? UndoableScriptTextView else { return }
        context.coordinator.text = $text
        context.coordinator.isFocused = isFocused

        if textView.string != text {
            context.coordinator.isApplyingExternalText = true
            textView.string = text
            context.coordinator.isApplyingExternalText = false
        }

        guard let window = textView.window else { return }
        if isFocused.wrappedValue, window.firstResponder !== textView {
            window.makeFirstResponder(textView)
        } else if !isFocused.wrappedValue, window.firstResponder === textView {
            window.makeFirstResponder(nil)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var isFocused: FocusState<Bool>.Binding
        var isApplyingExternalText = false

        init(text: Binding<String>, isFocused: FocusState<Bool>.Binding) {
            self.text = text
            self.isFocused = isFocused
        }

        func textDidBeginEditing(_ notification: Notification) {
            isFocused.wrappedValue = true
        }

        func textDidEndEditing(_ notification: Notification) {
            isFocused.wrappedValue = false
        }

        func textDidChange(_ notification: Notification) {
            guard !isApplyingExternalText,
                let textView = notification.object as? NSTextView
            else { return }
            text.wrappedValue = textView.string
        }
    }
}

/// Launch-type specific input fields extracted from SiteConfigView.
/// Renders URL, App, Finder, or Shell fields based on the current launchType.
struct SiteLaunchFields: View {
    @Binding var site: Site
    @Binding var isEditing: Bool
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

    // MARK: - Shell Fields

    private var shellFields: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Script")
                .font(DS.captionFont)
                .foregroundColor(DS.textSecondary)
            ScriptTextEditor(
                text: Binding(
                    get: { site.script ?? "" },
                    set: { site.script = $0 }
                ),
                isFocused: scriptFocused
            )
            .accessibilityLabel("Script")
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
