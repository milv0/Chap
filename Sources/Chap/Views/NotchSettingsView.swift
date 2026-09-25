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

    /// 팔레트에 노출하는 위젯 (빈 칸 제외 — 비우기는 슬롯의 x 버튼).
    private static let paletteWidgets: [NotchWidget] = [
        .sites, .apps, .folders, .scripts, .screenshots,
    ]

    /// Liquid Glass는 macOS 26(Tahoe)+ 에서만 제공된다.
    static var supportsLiquidGlass: Bool {
        if #available(macOS 26, *) { return true }
        return false
    }

    /// 콘텐츠 박스 배경 기본 프리셋. Guide는 GuideWindow 시그니처
    /// 색(DS.accent, DESIGN.md의 #3664FF)이다.
    private static let colorPresets: [(name: String, hex: String)] = [
        (name: "Black", hex: "#000000"),
        (name: "Guide", hex: "#3664FF"),
    ]

    private func slotWidget(_ index: Int) -> NotchWidget {
        vm.notchWidgets.indices.contains(index) ? vm.notchWidgets[index] : .none
    }

    /// 위젯을 슬롯에 배치한다. 같은 위젯이 다른 슬롯에 있으면 자리를 맞바꿔
    /// 중복 배치를 막는다.
    private func assign(_ widget: NotchWidget, to index: Int) {
        guard vm.notchWidgets.indices.contains(index) else { return }
        if widget != .none, let existing = vm.notchWidgets.firstIndex(of: widget),
            existing != index
        {
            vm.notchWidgets[existing] = vm.notchWidgets[index]
        }
        vm.notchWidgets[index] = widget
    }

    static func widgetName(_ widget: NotchWidget) -> String {
        switch widget {
        case .sites: return "Sites"
        case .apps: return "Apps"
        case .folders: return "Folders"
        case .scripts: return "Scripts"
        case .screenshots: return "Screenshots"
        case .drop: return "Drop"
        case .none: return "Empty"
        }
    }

    static func widgetSymbol(_ widget: NotchWidget) -> String {
        if let launchType = widget.launchType {
            return LauncherListPolicy.symbolName(for: launchType)
        }
        switch widget {
        case .screenshots: return "camera.viewfinder"
        case .drop: return "tray.and.arrow.down.fill"
        default: return "square.dashed"
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
                            VStack(alignment: .leading, spacing: 10) {
                                Text(
                                    "Drag a widget into a slot. Slots fill the panel from the left."
                                )
                                .font(.caption)
                                .foregroundColor(DS.textSecondary)

                                // 노치 패널의 4칸을 그대로 본뜬 드롭 보드.
                                HStack(spacing: 8) {
                                    ForEach(0..<NotchWidget.slotCount, id: \.self) { index in
                                        WidgetSlotBox(
                                            index: index,
                                            widget: slotWidget(index),
                                            onAssign: { assign($0, to: index) },
                                            onClear: { assign(.none, to: index) })
                                    }
                                }

                                // 배치 가능한 위젯 팔레트. 이미 배치된 위젯은 흐리게.
                                HStack(spacing: 8) {
                                    ForEach(Self.paletteWidgets, id: \.self) { widget in
                                        WidgetPaletteChip(
                                            widget: widget,
                                            isPlaced: vm.notchWidgets.contains(widget))
                                    }
                                }
                            }
                            .onChange(of: vm.notchWidgets) { _, _ in onSave() }
                        }

                        Section("Appearance") {
                            Picker("Style", selection: $vm.notchPanelStyle) {
                                Text("Custom").tag(NotchPanelStyle.custom)
                                if Self.supportsLiquidGlass {
                                    Text("Glass").tag(NotchPanelStyle.glass)
                                }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: vm.notchPanelStyle) { _, _ in onSave() }

                            if vm.notchPanelStyle == .glass {
                                Picker(
                                    "Glass Material",
                                    selection: $vm.notchGlassMaterial
                                ) {
                                    Text("Clear").tag(NotchGlassMaterial.clear)
                                    Text("Regular").tag(NotchGlassMaterial.regular)
                                }
                                .pickerStyle(.segmented)
                                .onChange(of: vm.notchGlassMaterial) { _, _ in
                                    // 재질 provider를 먼저 갱신한 뒤 새 패널을 열어
                                    // Clear/Regular 차이를 바로 보여준다.
                                    onSave()
                                    notchController?.previewGlassMaterial()
                                }

                                Picker(
                                    "Glass Appearance",
                                    selection: $vm.notchGlassAppearance
                                ) {
                                    Text("System").tag(NotchGlassAppearance.system)
                                    Text("Light").tag(NotchGlassAppearance.light)
                                    Text("Dark").tag(NotchGlassAppearance.dark)
                                }
                                .pickerStyle(.segmented)
                                .onChange(of: vm.notchGlassAppearance) { _, _ in
                                    // 먼저 저장해 controller provider를 갱신한 뒤,
                                    // 도커를 펼쳐 선택한 재질 appearance를 보여준다.
                                    onSave()
                                    notchController?.previewGlassAppearance()
                                }

                                Label(
                                    "System follows macOS automatically. Light and Dark "
                                        + "apply only to the notch Glass panel.",
                                    systemImage: "info.circle"
                                )
                                .font(.caption)
                                .foregroundColor(DS.textSecondary)
                            } else {
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

                                HStack {
                                    Text("Panel Color")
                                    Spacer()
                                    // 기본 프리셋: 검정(노치 연장)과 Chap 테마 블루
                                    // (GuideWindow 시그니처 색, DS.accent #3664FF).
                                    ForEach(Self.colorPresets, id: \.hex) { preset in
                                        ColorPresetSwatch(
                                            name: preset.name, hex: preset.hex,
                                            isSelected: vm.notchPanelColorHex == preset.hex
                                        ) {
                                            vm.notchPanelColorHex = preset.hex
                                        }
                                    }
                                    ColorPicker(
                                        "",
                                        selection: Binding(
                                            get: {
                                                NotchDockStyle.color(
                                                    fromHex: vm.notchPanelColorHex)
                                            },
                                            set: {
                                                vm.notchPanelColorHex = NotchDockStyle.hex(
                                                    from: $0)
                                            }
                                        ),
                                        supportsOpacity: false
                                    )
                                    .labelsHidden()
                                }
                                .onChange(of: vm.notchPanelColorHex) { _, _ in onSave() }

                                Label(
                                    "Drag the slider to preview the panel opacity live "
                                        + "under the notch. The menu bar strip stays black "
                                        + "as part of the notch.",
                                    systemImage: "info.circle"
                                )
                                .font(.caption)
                                .foregroundColor(DS.textSecondary)
                            }
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

/// 노치 패널의 한 칸을 본뜬 드롭 대상. 위젯을 떨어뜨려 배치하고,
/// 배치된 위젯은 다시 드래그해 다른 칸과 자리를 바꿀 수 있다.
private struct WidgetSlotBox: View {
    let index: Int
    let widget: NotchWidget
    let onAssign: (NotchWidget) -> Void
    let onClear: () -> Void

    @State private var isHovered = false
    @State private var isDropTargeted = false

    private var isEmpty: Bool { widget == .none }

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: NotchSettingsView.widgetSymbol(widget))
                .font(.system(size: 16))
                .foregroundColor(isEmpty ? DS.textTertiary : DS.accent)
            Text(isEmpty ? "Slot \(index + 1)" : NotchSettingsView.widgetName(widget))
                .font(DS.captionFont)
                .foregroundColor(isEmpty ? DS.textTertiary : DS.textPrimary)
                .lineLimit(1)
        }
        .frame(width: 92, height: 64)
        .background(
            RoundedRectangle(cornerRadius: DS.radiusSmall, style: .continuous)
                .fill(
                    isDropTargeted
                        ? DS.accentSurface
                        : (isEmpty ? Color.clear : DS.accentSoft))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.radiusSmall, style: .continuous)
                .strokeBorder(
                    isDropTargeted ? DS.accent : DS.border,
                    style: StrokeStyle(lineWidth: 1, dash: isEmpty ? [4, 3] : []))
        )
        .overlay(alignment: .topTrailing) {
            if isHovered && !isEmpty {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(DS.textTertiary)
                }
                .buttonStyle(.plain)
                .padding(3)
                .accessibilityLabel("Clear slot \(index + 1)")
            }
        }
        .onHover { isHovered = $0 }
        // 배치된 위젯은 슬롯에서 직접 끌어 다른 슬롯으로 옮길 수 있다.
        .draggable(widget.rawValue)
        .dropDestination(for: String.self) { items, _ in
            guard let raw = items.first, let dropped = NotchWidget(rawValue: raw) else {
                return false
            }
            onAssign(dropped)
            return true
        } isTargeted: {
            isDropTargeted = $0
        }
        .accessibilityLabel(
            "Slot \(index + 1): \(NotchSettingsView.widgetName(widget))")
    }
}

/// 배치 가능한 위젯 팔레트 칩. 슬롯으로 드래그해 넣는다.
private struct WidgetPaletteChip: View {
    let widget: NotchWidget
    let isPlaced: Bool

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: NotchSettingsView.widgetSymbol(widget))
                .font(DS.captionFont)
                .foregroundColor(DS.accent)
            Text(NotchSettingsView.widgetName(widget))
                .font(DS.captionFont)
                .foregroundColor(DS.textPrimary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(DS.cardBg)
        )
        .overlay(Capsule().strokeBorder(DS.border, lineWidth: 1))
        .opacity(isPlaced ? 0.45 : 1)
        .draggable(widget.rawValue)
        .help(
            isPlaced
                ? "Already placed — drag to move it to another slot."
                : "Drag into a slot to place this widget."
        )
        .accessibilityLabel("\(NotchSettingsView.widgetName(widget)) widget")
    }
}

/// 콘텐츠 박스 배경 프리셋 스와치. 선택된 프리셋은 액센트 링으로 표시한다.
private struct ColorPresetSwatch: View {
    let name: String
    let hex: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(NotchDockStyle.color(fromHex: hex))
                .frame(width: 18, height: 18)
                .overlay(Circle().strokeBorder(DS.border, lineWidth: 1))
                .overlay(
                    Circle()
                        .strokeBorder(DS.accent, lineWidth: isSelected ? 2 : 0)
                        .padding(-3)
                )
        }
        .buttonStyle(.plain)
        .help(name)
        .accessibilityLabel("\(name) panel color preset")
    }
}
