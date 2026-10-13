import SwiftUI

struct WorkspaceCaptureView: View {
    @ObservedObject var model: WorkspaceCaptureViewModel
    let onCancel: () -> Void
    let onSave: (String, [WorkspaceWindow]) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 520, height: 500)
        .background(DS.surfaceBg)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "rectangle.3.group")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(DS.accent)
                .frame(width: 38, height: 38)
                .background(DS.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("Capture Workspace")
                    .font(DS.headlineFont)
                    .foregroundColor(DS.textPrimary)
                Text("Saves app names, window titles, and positions. Stays on this Mac.")
                    .font(DS.captionFont)
                    .foregroundColor(DS.textSecondary)
            }
            Spacer()
        }
        .padding(20)
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading {
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.small)
                Text("Looking at open windows…")
                    .font(DS.bodyFont)
                    .foregroundColor(DS.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.candidates.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "macwindow.badge.xmark")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(DS.textTertiary)
                Text("No windows to capture")
                    .font(DS.headlineFont)
                    .foregroundColor(DS.textPrimary)
                Text("Arrange a standard app window, then try again.")
                    .font(DS.captionFont)
                    .foregroundColor(DS.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(model.candidates) { window in
                        candidateRow(window)
                    }
                }
                .padding(16)
            }
        }
    }

    private func candidateRow(_ window: WorkspaceWindow) -> some View {
        let selected = model.selectedIDs.contains(window.id)
        return Button {
            model.toggle(window.id)
        } label: {
            HStack(spacing: 12) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: window.applicationPath))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 30, height: 30)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(window.applicationName)
                        .font(DS.bodyFont.weight(.medium))
                        .foregroundColor(DS.textPrimary)
                        .lineLimit(1)
                    Text(detailText(for: window))
                        .font(DS.captionFont)
                        .foregroundColor(DS.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                WorkspaceFramePreview(frame: window.frame)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundColor(selected ? DS.accent : DS.textTertiary)
            }
            .padding(.horizontal, 12)
            .frame(height: 58)
            .background(selected ? DS.accentSoft : DS.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selected ? DS.accent.opacity(0.35) : DS.border, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "\(window.applicationName), \(window.displayName ?? "display"), "
                + (selected ? "selected" : "not selected")
        )
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var footer: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Name")
                    .font(DS.captionFont)
                    .foregroundColor(DS.textSecondary)
                TextField("Deep Work", text: $model.name)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Workspace name")
            }
            HStack {
                Text("\(model.selectedWindows.count) selected")
                    .font(DS.captionFont)
                    .foregroundColor(DS.textSecondary)
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    onSave(model.name, model.selectedWindows)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!model.canSave)
            }
        }
        .padding(16)
    }

    private func detailText(for window: WorkspaceWindow) -> String {
        let display = window.displayName ?? "Unknown display"
        let title = window.windowTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return title.isEmpty ? display : "\(display) · \(title)"
    }
}

private struct WorkspaceFramePreview: View {
    let frame: WorkspaceFrame

    var body: some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: 3)
                .fill(DS.accent.opacity(0.22))
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(DS.accent, lineWidth: 1))
                .frame(
                    width: max(geometry.size.width * frame.width, 5),
                    height: max(geometry.size.height * frame.height, 4)
                )
                .offset(
                    x: geometry.size.width * frame.left,
                    y: geometry.size.height * frame.top)
        }
        .frame(width: 54, height: 34)
        .background(DS.border.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(DS.border, lineWidth: 1))
        .accessibilityHidden(true)
    }
}
