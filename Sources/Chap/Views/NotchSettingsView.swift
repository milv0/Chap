import Cocoa
import SwiftUI

/// Notch 탭. 노치 런처 전용 설정을 모아 두어 이후 노치 기능이 늘어나도
/// General이 비대해지지 않는다. 세부 설정은 활성화 상태에서만 펼쳐진다.
struct NotchSettingsView: View {
    @ObservedObject var vm: SettingsViewModel
    let onSave: () -> Void

    /// 연결된 화면 중 하나라도 노치가 있으면 true. 판별 규칙은 ChapCore 정책을 따른다.
    /// (렌더 도구) 노치가 없는 환경에서도 세부 설정을 그린다.
    static var previewForcesNotch = false

    private static var hasNotchScreen: Bool {
        previewForcesNotch
            || NSScreen.screens.contains { screen in
                NotchLauncherPolicy.hasNotch(topSafeAreaInset: screen.safeAreaInsets.top)
            }
    }

    /// 실시간 프리뷰용 컨트롤러. 설정 창은 AppDelegate가 소유한 컨트롤러를 빌린다.
    private var notchController: NotchLauncherController? {
        (NSApp.delegate as? AppDelegate)?.notchLauncher
    }

    /// 팔레트에 노출하는 위젯 (빈 칸 제외 — 비우기는 슬롯의 x 버튼).
    /// 끌어다 놓는 위젯. 선반(Screenshots·Downloads)은 고정 칸에서 켜고 끄기만 하므로 팔레트에 없다.
    private static let paletteWidgets: [NotchWidget] = [.sites, .apps, .folders, .awake, .todo]

    /// Liquid Glass는 macOS 26(Tahoe)+ 에서만 제공된다.
    static var supportsLiquidGlass: Bool {
        if #available(macOS 26, *) { return true }
        return false
    }

    /// 콘텐츠 박스 배경 기본 프리셋. Mist는 푸른 기가 도는 밝은 회색
    /// (#E8ECF8)으로, 밝은 배경용 텍스트/아이콘 대비가 자동 적용된다.
    private static let colorPresets: [(name: String, hex: String)] = [
        (name: "Black", hex: "#000000"),
        (name: "Mist", hex: "#E8ECF8"),
    ]

    private func slotWidget(_ index: Int) -> NotchWidget {
        vm.notchWidgets.indices.contains(index) ? vm.notchWidgets[index] : .none
    }

    /// 위젯을 슬롯에 배치한다. 같은 위젯이 다른 슬롯에 있으면 자리를 맞바꿔
    /// 중복 배치를 막는다. 선반은 앞쪽 선반 칸에만, 다른 위젯은 뒤쪽 칸에만 놓인다(`fits(slot:)`).
    @discardableResult
    private func assign(_ widget: NotchWidget, to index: Int) -> Bool {
        guard vm.notchWidgets.indices.contains(index), widget.fits(slot: index) else {
            return false
        }
        if widget != .none, let existing = vm.notchWidgets.firstIndex(of: widget),
            existing != index
        {
            vm.notchWidgets[existing] = vm.notchWidgets[index]
        }
        vm.notchWidgets[index] = widget
        return true
    }

    /// 보드의 칸 묶음: 작은 제목 + 칸들. 선반과 위젯 칸을 떨어뜨려 노치 왼쪽부터의 순서를 그대로 보여 준다.
    private func slotGroup<Content: View>(
        title: String, systemImage: String?, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 3) {
                if let systemImage {
                    Image(systemName: systemImage).font(.system(size: 8))
                }
                Text(title)
            }
            .font(.caption2.weight(.medium))
            .foregroundColor(DS.textTertiary)
            HStack(spacing: 6) { content() }
        }
    }

    static func widgetName(_ widget: NotchWidget) -> String {
        switch widget {
        case .sites: return "Sites"
        case .apps: return "Apps"
        case .folders: return "Finder"
        case .screenshots: return "Screenshots"
        case .downloads: return "Downloads"
        case .awake: return "Focus"
        case .todo: return "To-do"
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
        case .downloads: return "arrow.down.circle"
        case .awake: return "bolt.fill"
        case .todo: return "checklist"
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
                        // 레이아웃: 노치 칸을 왼쪽부터 그대로 본뜬 보드. 선반 두 칸과 위젯 네 칸을 떨어뜨려 묶는다.
                        Section {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .top, spacing: 14) {
                                    slotGroup(title: "Default", systemImage: "lock.fill") {
                                        ForEach(0..<NotchWidget.shelfSlotCount, id: \.self) {
                                            index in
                                            let shelf = NotchWidget.shelfSlots[index]
                                            ShelfSlotToggle(
                                                index: index, shelf: shelf,
                                                isOn: slotWidget(index) == shelf
                                            ) {
                                                vm.notchWidgets[index] =
                                                    slotWidget(index) == shelf ? .none : shelf
                                            }
                                        }
                                    }
                                    slotGroup(title: "Widgets", systemImage: nil) {
                                        ForEach(
                                            NotchWidget.shelfSlotCount..<NotchWidget.slotCount,
                                            id: \.self
                                        ) { index in
                                            WidgetSlotBox(
                                                index: index,
                                                widget: slotWidget(index),
                                                onAssign: { assign($0, to: index) },
                                                onClear: { _ = assign(.none, to: index) })
                                        }
                                    }
                                }

                                // 아직 놓지 않은 위젯만 한 줄로. 다 놓았으면 줄 자체가 없다.
                                let unplaced = Self.paletteWidgets.filter {
                                    !vm.notchWidgets.contains($0)
                                }
                                if !unplaced.isEmpty {
                                    HStack(spacing: 6) {
                                        Text("Add")
                                            .font(.caption)
                                            .foregroundColor(DS.textSecondary)
                                        ForEach(unplaced, id: \.self) { widget in
                                            WidgetPaletteChip(widget: widget, isPlaced: false)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                            .onChange(of: vm.notchWidgets) { _, _ in onSave() }
                        } header: {
                            Text("Layout")
                        } footer: {
                            Text(
                                "Click Screenshots or Downloads to turn it on or off. Drag widgets onto slots 3–6, "
                                    + "or right-click a slot."
                            )
                            .font(.caption)
                            .foregroundColor(DS.textSecondary)
                        }

                        // 검정 띠 오른쪽 도구 아이콘. 칸이 아니라 띠에 붙는 아이콘이라 따로 묶는다.
                        Section("Top Strip") {
                            Toggle(isOn: $vm.notchMirrorEnabled) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Mirror")
                                    Text("Check your camera. It turns on only when you click it.")
                                        .font(.caption)
                                        .foregroundColor(DS.textSecondary)
                                }
                            }
                            .onChange(of: vm.notchMirrorEnabled) { _, _ in onSave() }

                            Toggle(isOn: $vm.notchQuickNoteEnabled) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Quick Note")
                                    Text(
                                        "Write across the notch, or pop the note into its own window."
                                    )
                                    .font(.caption)
                                    .foregroundColor(DS.textSecondary)
                                }
                            }
                            .onChange(of: vm.notchQuickNoteEnabled) { _, _ in onSave() }
                        }

                        Section("Appearance") {
                            Picker("Style", selection: $vm.notchPanelStyle) {
                                Text("Custom").tag(NotchPanelStyle.custom)
                                if Self.supportsLiquidGlass {
                                    Text("Glass").tag(NotchPanelStyle.glass)
                                }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: vm.notchPanelStyle) { _, _ in
                                notchController?.endOpacityPreview()
                                onSave()
                            }

                            if vm.notchPanelStyle == .glass {
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
                                    onSave()
                                    notchController?.previewGlassAppearance()
                                }

                                // 재질은 appearance와 독립적으로 사용자가 고른다.
                                Picker(
                                    "Glass Material",
                                    selection: $vm.notchGlassMaterial
                                ) {
                                    Text("Clear").tag(NotchGlassMaterial.clear)
                                    Text("Regular").tag(NotchGlassMaterial.regular)
                                }
                                .pickerStyle(.segmented)
                                .onChange(of: vm.notchGlassMaterial) { _, _ in
                                    onSave()
                                    notchController?.previewGlassMaterial()
                                }

                                Text(
                                    "System follows macOS. Clear is see-through; Regular adds contrast."
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
                                    // 기본 프리셋: 검정(노치 연장)과 밝은 Mist(#E8ECF8).
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
                                .onChange(of: vm.notchPanelColorHex) { _, newValue in
                                    onSave()
                                    notchController?.previewCustomColor(newValue)
                                }

                                Text("Changes preview live under the notch.")
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

/// 고정 선반 칸. 끌어 옮기거나 다른 위젯을 놓을 수 없고, 누르면 켜고 끈다.
private struct ShelfSlotToggle: View {
    let index: Int
    let shelf: NotchWidget
    let isOn: Bool
    let toggle: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: toggle) {
            VStack(spacing: 5) {
                Image(systemName: NotchSettingsView.widgetSymbol(shelf))
                    .font(.system(size: 16))
                    .foregroundColor(isOn ? DS.accent : DS.textTertiary)
                Text(NotchSettingsView.widgetName(shelf))
                    .font(DS.captionFont)
                    .foregroundColor(isOn ? DS.textPrimary : DS.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 3)
            .frame(width: 72, height: 58)
            .background(
                RoundedRectangle(cornerRadius: DS.radiusSmall, style: .continuous)
                    .fill(isOn ? DS.accentSoft : (isHovered ? DS.border.opacity(0.25) : .clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.radiusSmall, style: .continuous)
                    .strokeBorder(
                        DS.border, style: StrokeStyle(lineWidth: 1, dash: isOn ? [] : [4, 3]))
            )
            .overlay(alignment: .topTrailing) {
                // 켜져 있으면 체크, 꺼져 있으면 빈 동그라미. 누르면 바뀐다.
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 11))
                    .foregroundColor(isOn ? DS.accent : DS.textTertiary)
                    .padding(4)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(
            "\(NotchSettingsView.widgetName(shelf)) always sits in slot \(index + 1). "
                + "Click to turn it \(isOn ? "off" : "on")."
        )
        .accessibilityLabel("\(NotchSettingsView.widgetName(shelf)), slot \(index + 1)")
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isToggle)
    }
}

/// 노치 패널의 한 칸을 본뜬 드롭 대상. 위젯을 떨어뜨려 배치하고,
/// 배치된 위젯은 다시 드래그해 다른 칸과 자리를 바꿀 수 있다.
private struct WidgetSlotBox: View {
    let index: Int
    let widget: NotchWidget
    /// 놓을 수 있으면 true. 선반 칸에 다른 위젯, 위젯 칸에 선반을 놓으면 false라 되돌아간다.
    let onAssign: (NotchWidget) -> Bool
    let onClear: () -> Void

    @State private var isHovered = false
    @State private var isDropTargeted = false

    private var isEmpty: Bool { widget == .none }
    private var isShelfSlot: Bool { index < NotchWidget.shelfSlotCount }
    /// 이 칸에 놓을 수 있는 위젯(메뉴·VoiceOver 동작).
    private var choices: [NotchWidget] {
        [.sites, .apps, .folders, .screenshots, .downloads, .awake, .todo].filter {
            $0.fits(slot: index)
        }
    }

    var body: some View {
        VStack(spacing: 5) {
            Image(
                systemName: isEmpty && isShelfSlot
                    ? "tray" : NotchSettingsView.widgetSymbol(widget)
            )
            .font(.system(size: 16))
            .foregroundColor(isEmpty ? DS.textTertiary : DS.accent)
            Text(
                isEmpty
                    ? (isShelfSlot ? "Off" : "Empty")
                    : NotchSettingsView.widgetName(widget)
            )
            .font(DS.captionFont)
            .foregroundColor(isEmpty ? DS.textTertiary : DS.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 3)
        .frame(width: 72, height: 58)
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
        // Drag가 어려운 키보드·VoiceOver 사용자를 위한 동일 기능 메뉴.
        // Drag가 어려운 키보드·VoiceOver 사용자를 위한 동일 기능 메뉴. 이 칸에 놓을 수 있는 위젯만 보인다.
        .contextMenu {
            ForEach(choices, id: \.self) { choice in
                Button(NotchSettingsView.widgetName(choice)) { _ = onAssign(choice) }
            }
            if !isEmpty {
                Divider()
                Button("Clear Slot", action: onClear)
            }
        }
        // VoiceOver rotor actions: drag/drop 없이 배치·비우기 가능.
        .accessibilityActions {
            ForEach(choices, id: \.self) { choice in
                Button("Place \(NotchSettingsView.widgetName(choice))") { _ = onAssign(choice) }
            }
            Button("Clear Slot", action: onClear)
        }
        // 배치된 위젯은 슬롯에서 직접 끌어 다른 슬롯으로 옮길 수 있다.
        .draggable(widget.rawValue)
        .dropDestination(for: String.self) { items, _ in
            guard let raw = items.first, let dropped = NotchWidget(rawValue: raw) else {
                return false
            }
            return onAssign(dropped)
        } isTargeted: {
            isDropTargeted = $0
        }
        .accessibilityLabel(
            "Slot \(index + 1): \(NotchSettingsView.widgetName(widget))"
        )
        .help(isShelfSlot ? "Default slot: Screenshots or Downloads" : "Widget slot")
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
