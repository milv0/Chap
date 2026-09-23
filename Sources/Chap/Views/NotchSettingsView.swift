import Cocoa
import SwiftUI

/// Notch 탭. 노치 런처 전용 설정을 모아 두어 이후 노치 기능이 늘어나도
/// General이 비대해지지 않는다. 세부 설정은 활성화 상태에서만 펼쳐진다.
struct NotchSettingsView: View {
    @ObservedObject var vm: SettingsViewModel
    let onSave: () -> Void

    /// 연결된 화면 중 하나라도 노치가 있으면 true. 판별 규칙은 ChapCore 정책을 따른다.
    private static var hasNotchScreen: Bool {
        NSScreen.screens.contains { screen in
            NotchLauncherPolicy.hasNotch(topSafeAreaInset: screen.safeAreaInsets.top)
        }
    }

    /// 실시간 프리뷰용 컨트롤러. 설정 창은 AppDelegate가 소유한 컨트롤러를 빌린다.
    private var notchController: NotchLauncherController? {
        (NSApp.delegate as? AppDelegate)?.notchLauncher
    }

    /// 슬롯 배열의 개별 칸 바인딩. 배열 길이는 모델이 4로 보장한다.
    private func slotBinding(_ index: Int) -> Binding<NotchWidget> {
        Binding(
            get: { vm.notchWidgets.indices.contains(index) ? vm.notchWidgets[index] : .none },
            set: { newValue in
                guard vm.notchWidgets.indices.contains(index) else { return }
                vm.notchWidgets[index] = newValue
            })
    }

    private static func widgetName(_ widget: NotchWidget) -> String {
        switch widget {
        case .sites: return "Sites"
        case .apps: return "Apps"
        case .folders: return "Folders"
        case .scripts: return "Scripts"
        case .screenshots: return "Screenshots"
        case .none: return "Empty"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer(minLength: 0)
                Form {
                    Section("Notch Launcher") {
                        Toggle("Show Launchers Under the Notch", isOn: $vm.notchLauncherEnabled)
                            .disabled(!Self.hasNotchScreen)
                            .help(
                                "Show the launcher list in a panel under the notch. "
                                    + "The status bar menu keeps working either way."
                            )
                            .onChange(of: vm.notchLauncherEnabled) { _, _ in onSave() }

                        if !Self.hasNotchScreen {
                            Label(
                                "This Mac has no notch display, so the notch launcher "
                                    + "is unavailable.",
                                systemImage: "info.circle"
                            )
                            .font(.caption)
                            .foregroundColor(DS.textSecondary)
                        }
                    }

                    // 세부 설정은 활성화 상태에서만 펼쳐진다.
                    if Self.hasNotchScreen && vm.notchLauncherEnabled {
                        Section("Widgets") {
                            // 4칸 각각에 배치할 위젯을 고른다. 왼쪽 칸부터 순서대로.
                            ForEach(0..<NotchWidget.slotCount, id: \.self) { index in
                                Picker(
                                    "Slot \(index + 1)",
                                    selection: slotBinding(index)
                                ) {
                                    ForEach(NotchWidget.allCases, id: \.self) { widget in
                                        Text(Self.widgetName(widget)).tag(widget)
                                    }
                                }
                                .onChange(of: vm.notchWidgets) { _, _ in onSave() }
                            }

                            Label(
                                "Slots fill the panel from the left. Empty slots are "
                                    + "skipped.",
                                systemImage: "info.circle"
                            )
                            .font(.caption)
                            .foregroundColor(DS.textSecondary)
                        }

                        Section("Appearance") {
                            Picker("Style", selection: $vm.notchPanelStyle) {
                                Text("Black").tag(NotchPanelStyle.black)
                                Text("Iceberg").tag(NotchPanelStyle.iceberg)
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: vm.notchPanelStyle) { _, _ in onSave() }

                            HStack {
                                Text("Panel Opacity")
                                Slider(
                                    value: $vm.notchPanelOpacity,
                                    in: Config.notchPanelOpacityRange
                                ) { editing in
                                    // 드래그 시작 시 패널을 띄워 고정하고,
                                    // 놓는 순간 고정을 풀고 저장한다.
                                    if editing {
                                        notchController?.beginOpacityPreview()
                                    } else {
                                        notchController?.endOpacityPreview()
                                        onSave()
                                    }
                                }
                                Text("\(Int(vm.notchPanelOpacity * 100))%")
                                    .font(.caption)
                                    .foregroundColor(DS.textSecondary)
                                    .frame(width: 38, alignment: .trailing)
                                    .monospacedDigit()
                            }
                            .onChange(of: vm.notchPanelOpacity) { _, newValue in
                                // 드래그 중 실시간 반영.
                                notchController?.updateOpacityPreview(newValue)
                            }

                            Label(
                                "Drag the slider to preview the panel opacity live "
                                    + "under the notch.",
                                systemImage: "info.circle"
                            )
                            .font(.caption)
                            .foregroundColor(DS.textSecondary)
                        }
                    }
                }
                .formStyle(.grouped)
                .frame(maxWidth: 560)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.surfaceBg)
    }
}
