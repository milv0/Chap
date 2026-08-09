import SwiftUI

/// Paste-JSON sheet presented from SettingsView's ··· menu.
/// Preserves the behaviour: on Apply failure the text and sheet remain open;
/// on success the sheet is dismissed.
struct SettingsPasteJSONSheet: View {
    @Binding var pasteJSONText: String
    let onCancel: () -> Void
    /// Returns `true` when the JSON was applied successfully (sheet should close).
    let onApply: (String) -> Bool

    var body: some View {
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
                Button("Cancel") { onCancel() }
                    .buttonStyle(.plain)
                    .foregroundColor(DS.textSecondary)
                Spacer()
                PrimaryButton(title: "Apply") {
                    if onApply(pasteJSONText) {
                        onCancel()  // dismiss sheet on success
                    }
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
}
