//
//  QuickAccess.swift
//  QuickAccess - Menubar app for quick website launching
//
//  Created by Mingyu Park
//  Contact: uqwe00@gmail.com / brianmg@naver.com
//  © 2026 Mingyu Park. All rights reserved.
//

import Cocoa

enum Defaults {
    static let appVersion = "1.1.0"
    static let defaultWidth = 800
    static let defaultHeight = 600
    static let defaultX = 100
    static let defaultY = 100
    static let resizeDelay = 0.2
    static let coldStartDelay = 3.0
    static let resizeRetries = 20
    static let retryInterval = 0.2
}

// MARK: - Data Models for config persistence

struct Site: Codable {
    var name: String
    var url: String
    var width: Int
    var height: Int
    var x: Int
    var y: Int
}

struct Config: Codable {
    var runInBackground: Bool
    var sites: [Site]

    init(runInBackground: Bool = true, sites: [Site]) {
        self.runInBackground = runInBackground
        self.sites = sites
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        runInBackground = try container.decodeIfPresent(Bool.self, forKey: .runInBackground) ?? true
        sites = try container.decode([Site].self, forKey: .sites)
    }
}

// MARK: - Layout Preview Button

class LayoutPreviewButton: NSView {
    var layoutIndex: Int = 0
    var isSelected: Bool = false { didSet { needsDisplay = true } }
    var onClick: ((Int) -> Void)?
    private var isHovered: Bool = false
    private var trackingArea: NSTrackingArea?

    // Returns the filled rect proportional to the button bounds for each layout
    private func filledRect() -> NSRect {
        let b = bounds.insetBy(dx: 2, dy: 2)
        switch layoutIndex {
        case 0: // Center - small rect in middle
            let w = b.width * 0.4, h = b.height * 0.4
            return NSRect(x: b.origin.x + (b.width - w)/2, y: b.origin.y + (b.height - h)/2, width: w, height: h)
        case 1: return NSRect(x: b.origin.x, y: b.origin.y, width: b.width/2, height: b.height) // Left Half
        case 2: return NSRect(x: b.midX, y: b.origin.y, width: b.width/2, height: b.height) // Right Half
        case 3: return NSRect(x: b.origin.x, y: b.midY, width: b.width, height: b.height/2) // Top Half
        case 4: return NSRect(x: b.origin.x, y: b.origin.y, width: b.width, height: b.height/2) // Bottom Half
        case 5: return NSRect(x: b.origin.x, y: b.midY, width: b.width/2, height: b.height/2) // Top-Left
        case 6: return NSRect(x: b.midX, y: b.midY, width: b.width/2, height: b.height/2) // Top-Right
        case 7: return NSRect(x: b.origin.x, y: b.origin.y, width: b.width/2, height: b.height/2) // Bottom-Left
        case 8: return NSRect(x: b.midX, y: b.origin.y, width: b.width/2, height: b.height/2) // Bottom-Right
        default: return .zero
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let b = bounds.insetBy(dx: 2, dy: 2)
        // Screen outline
        NSColor.lightGray.setStroke()
        let outline = NSBezierPath(rect: b)
        outline.lineWidth = 1
        outline.stroke()
        // Filled area
        NSColor(calibratedRed: 139/255, green: 92/255, blue: 246/255, alpha: 1).setFill()
        NSBezierPath(rect: filledRect()).fill()
        // Selection/hover border
        if isSelected {
            NSColor.systemBlue.setStroke()
            let sel = NSBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5))
            sel.lineWidth = 2
            sel.stroke()
        } else if isHovered {
            NSColor.systemBlue.withAlphaComponent(0.4).setStroke()
            let hov = NSBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5))
            hov.lineWidth = 1.5
            hov.stroke()
        }
    }

    override func mouseDown(with event: NSEvent) { onClick?(layoutIndex) }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let t = trackingArea { removeTrackingArea(t) }
        trackingArea = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow], owner: self)
        addTrackingArea(trackingArea!)
    }
    override func mouseEntered(with event: NSEvent) { isHovered = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { isHovered = false; needsDisplay = true }
}

// MARK: - Minimap Preview View

class MinimapView: NSView {
    var siteX: CGFloat = 0
    var siteY: CGFloat = 0
    var siteW: CGFloat = 0
    var siteH: CGFloat = 0
    var hasSelection: Bool = false

    override func draw(_ dirtyRect: NSRect) {
        let b = bounds.insetBy(dx: 2, dy: 2)
        // Gray screen outline
        NSColor(calibratedWhite: 0.85, alpha: 1).setFill()
        NSBezierPath(rect: b).fill()
        NSColor.gray.setStroke()
        let outline = NSBezierPath(rect: b)
        outline.lineWidth = 1
        outline.stroke()

        guard hasSelection, let screen = NSScreen.main else { return }
        let screenW = screen.frame.width
        let screenH = screen.frame.height
        guard siteW > 0, siteH > 0 else { return }

        // Scale site rect to minimap
        let scaleX = b.width / screenW
        let scaleY = b.height / screenH
        let rect = NSRect(x: b.origin.x + siteX * scaleX,
                          y: b.origin.y + (screenH - siteY - siteH) * scaleY,
                          width: siteW * scaleX,
                          height: siteH * scaleY)
        NSColor(calibratedRed: 139/255, green: 92/255, blue: 246/255, alpha: 0.5).setFill()
        NSBezierPath(rect: rect).fill()
        NSColor(calibratedRed: 139/255, green: 92/255, blue: 246/255, alpha: 1).setStroke()
        let border = NSBezierPath(rect: rect)
        border.lineWidth = 1
        border.stroke()
    }

    func update(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, selected: Bool) {
        siteX = x; siteY = y; siteW = w; siteH = h; hasSelection = selected
        needsDisplay = true
    }
}

// MARK: - Settings Window Controller

class SettingsWindowController: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate, NSTextFieldDelegate {
    var window: NSWindow!
    var tableView: NSTableView!
    var sites: [Site] = []
    var nameField: NSTextField!
    var urlField: NSTextField!
    var widthField: NSTextField!
    var heightField: NSTextField!
    var xField: NSTextField!
    var yField: NSTextField!
    var xMaxLabel: NSTextField!
    var yMaxLabel: NSTextField!
    var layoutPopup: NSPopUpButton!
    var sizePopup: NSPopUpButton!
    var backgroundCheckbox: NSButton!
    var saveBtn: NSButton!
    var layoutButtons: [LayoutPreviewButton] = []
    var minimapView: MinimapView!
    var runInBackground: Bool = true
    var onSave: (([Site], Bool) -> Void)?
    var onReload: (() -> Void)?
    var isUpdatingFromPreset = false
    var previousSelectedRow = -1

    func showWindow(sites: [Site], runInBackground: Bool, onSave: @escaping ([Site], Bool) -> Void) {
        self.sites = sites
        self.runInBackground = runInBackground
        self.onSave = onSave

        if window == nil {
            setupWindow()
        }
        tableView.reloadData()
        clearFields()
        previousSelectedRow = -1
        backgroundCheckbox?.state = runInBackground ? .on : .off

        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: Window setup — builds the settings UI layout
    func setupWindow() {
        guard let screen = NSScreen.main else { return }

        let winWidth: CGFloat = 820
        let winHeight: CGFloat = 750

        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: winWidth, height: winHeight),
                          styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.title = "QuickAccess Settings"
        window.minSize = NSSize(width: winWidth, height: winHeight)
        window.center()
        window.delegate = self

        guard let content = window.contentView else { return }
        let margin: CGFloat = 16
        let tableWidth: CGFloat = 180
        let bottomBarHeight: CGFloat = 50

        // Left panel: site list table with full height
        let tableTop = winHeight - margin
        let tableBottom = bottomBarHeight + margin + 36
        let scrollView = NSScrollView(frame: NSRect(x: margin, y: tableBottom, width: tableWidth, height: tableTop - tableBottom))
        scrollView.autoresizingMask = [.height]
        tableView = NSTableView()
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        col.title = "Sites"
        col.width = tableWidth - 20
        tableView.addTableColumn(col)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.headerView = NSTableHeaderView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        content.addSubview(scrollView)

        // Add/Remove/↑/↓ buttons below table
        let btnY = bottomBarHeight + margin
        let addBtn = NSButton(frame: NSRect(x: margin, y: btnY, width: 50, height: 28))
        addBtn.title = "Add"
        addBtn.bezelStyle = .rounded
        addBtn.target = self
        addBtn.action = #selector(addSite)
        content.addSubview(addBtn)

        let removeBtn = NSButton(frame: NSRect(x: margin + 58, y: btnY, width: 65, height: 28))
        removeBtn.title = "Remove"
        removeBtn.bezelStyle = .rounded
        removeBtn.target = self
        removeBtn.action = #selector(removeSite)
        content.addSubview(removeBtn)

        let upBtn = NSButton(frame: NSRect(x: margin + 58 + 73, y: btnY + 2, width: 24, height: 24))
        upBtn.title = "↑"
        upBtn.bezelStyle = .rounded
        upBtn.target = self
        upBtn.action = #selector(moveSiteUp)
        content.addSubview(upBtn)

        let downBtn = NSButton(frame: NSRect(x: margin + 58 + 73 + 32, y: btnY + 2, width: 24, height: 24))
        downBtn.title = "↓"
        downBtn.bezelStyle = .rounded
        downBtn.target = self
        downBtn.action = #selector(moveSiteDown)
        content.addSubview(downBtn)

        // Right panel: NSBox grouping form fields
        let boxX = margin + tableWidth + margin
        let boxWidth = winWidth - boxX - margin
        let boxHeight = winHeight - bottomBarHeight - margin * 2
        let box = NSBox(frame: NSRect(x: boxX, y: bottomBarHeight + margin, width: boxWidth, height: boxHeight))
        box.title = "Site Configuration"
        box.titlePosition = .atTop
        box.boxType = .primary
        box.autoresizingMask = [.height, .width]
        content.addSubview(box)

        let boxContent = box.contentView!
        let labelWidth: CGFloat = 70
        let labelFont = NSFont.systemFont(ofSize: 13)
        let formX: CGFloat = 4
        let fieldX: CGFloat = labelWidth + 12
        let fieldWidth: CGFloat = 250
        let fieldHeight: CGFloat = 22

        let screenW = Int(screen.frame.width)
        let screenH = Int(screen.frame.height)

        // Top-down y calculation
        let boxInnerHeight = boxHeight - 30 // account for NSBox title
        var y = boxInnerHeight - 30 // start from top with padding

        // Screen info label
        let screenLabel = NSTextField(labelWithString: "Screen: \(screenW) × \(screenH)")
        screenLabel.frame = NSRect(x: fieldX, y: y, width: fieldWidth, height: 18)
        screenLabel.font = NSFont.systemFont(ofSize: 11)
        screenLabel.textColor = .secondaryLabelColor
        boxContent.addSubview(screenLabel)
        y -= 35

        // Visual layout preview buttons (9 buttons)
        let lbtnWidth: CGFloat = 44
        let lbtnHeight: CGFloat = round(lbtnWidth * CGFloat(screenH) / CGFloat(screenW))
        let lbtnSpacing: CGFloat = 4
        let totalBtnWidth = 9 * lbtnWidth + 8 * lbtnSpacing
        let btnStartX = (boxWidth - 20 - totalBtnWidth) / 2
        layoutButtons = []
        for i in 0..<9 {
            let btn = LayoutPreviewButton(frame: NSRect(x: btnStartX + CGFloat(i) * (lbtnWidth + lbtnSpacing), y: y, width: lbtnWidth, height: lbtnHeight))
            btn.layoutIndex = i
            btn.onClick = { [weak self] idx in self?.layoutButtonClicked(idx) }
            boxContent.addSubview(btn)
            layoutButtons.append(btn)
        }
        y -= 40

        // Layout dropdown
        let layoutLabel = NSTextField(labelWithString: "Layout:")
        layoutLabel.frame = NSRect(x: formX, y: y, width: labelWidth, height: fieldHeight)
        layoutLabel.alignment = .right
        layoutLabel.font = labelFont
        boxContent.addSubview(layoutLabel)
        layoutPopup = NSPopUpButton(frame: NSRect(x: fieldX, y: y, width: fieldWidth, height: fieldHeight), pullsDown: false)
        layoutPopup.addItems(withTitles: ["Custom", "Center", "Left Half", "Right Half", "Top Half", "Bottom Half", "Top-Left", "Top-Right", "Bottom-Left", "Bottom-Right"])
        layoutPopup.target = self
        layoutPopup.action = #selector(layoutChanged(_:))
        boxContent.addSubview(layoutPopup)
        y -= 30

        // Size dropdown
        let sizeLabel = NSTextField(labelWithString: "Size:")
        sizeLabel.frame = NSRect(x: formX, y: y, width: labelWidth, height: fieldHeight)
        sizeLabel.alignment = .right
        sizeLabel.font = labelFont
        boxContent.addSubview(sizeLabel)
        sizePopup = NSPopUpButton(frame: NSRect(x: fieldX, y: y, width: fieldWidth, height: fieldHeight), pullsDown: false)
        sizePopup.addItems(withTitles: ["Custom", "Tiny (400x200)", "Mini (600x300)", "Medium (800x500)", "Large (1000x700)", "XL (1200x800)", "Wide (1000x400)", "Tall (500x800)", "Full (1400x900)"])
        sizePopup.target = self
        sizePopup.action = #selector(sizeChanged(_:))
        boxContent.addSubview(sizePopup)
        y -= 30

        // Name field
        let nameLbl = NSTextField(labelWithString: "Name:")
        nameLbl.frame = NSRect(x: formX, y: y, width: labelWidth, height: fieldHeight)
        nameLbl.alignment = .right
        nameLbl.font = labelFont
        boxContent.addSubview(nameLbl)
        nameField = NSTextField(frame: NSRect(x: fieldX, y: y, width: fieldWidth, height: fieldHeight))
        boxContent.addSubview(nameField)
        y -= 30

        // URL field
        let urlLbl = NSTextField(labelWithString: "URL:")
        urlLbl.frame = NSRect(x: formX, y: y, width: labelWidth, height: fieldHeight)
        urlLbl.alignment = .right
        urlLbl.font = labelFont
        boxContent.addSubview(urlLbl)
        urlField = NSTextField(frame: NSRect(x: fieldX, y: y, width: fieldWidth, height: fieldHeight))
        boxContent.addSubview(urlField)
        y -= 30

        // Width field
        let widthLbl = NSTextField(labelWithString: "Width:")
        widthLbl.frame = NSRect(x: formX, y: y, width: labelWidth, height: fieldHeight)
        widthLbl.alignment = .right
        widthLbl.font = labelFont
        boxContent.addSubview(widthLbl)
        widthField = NSTextField(frame: NSRect(x: fieldX, y: y, width: fieldWidth, height: fieldHeight))
        widthField.placeholderString = "max: \(screenW)"
        widthField.delegate = self
        boxContent.addSubview(widthField)
        y -= 30

        // Height field
        let heightLbl = NSTextField(labelWithString: "Height:")
        heightLbl.frame = NSRect(x: formX, y: y, width: labelWidth, height: fieldHeight)
        heightLbl.alignment = .right
        heightLbl.font = labelFont
        boxContent.addSubview(heightLbl)
        heightField = NSTextField(frame: NSRect(x: fieldX, y: y, width: fieldWidth, height: fieldHeight))
        heightField.placeholderString = "max: \(screenH)"
        heightField.delegate = self
        boxContent.addSubview(heightField)
        y -= 30

        // X field + xMaxLabel
        let xLbl = NSTextField(labelWithString: "X:")
        xLbl.frame = NSRect(x: formX, y: y, width: labelWidth, height: fieldHeight)
        xLbl.alignment = .right
        xLbl.font = labelFont
        boxContent.addSubview(xLbl)
        xField = NSTextField(frame: NSRect(x: fieldX, y: y, width: fieldWidth, height: fieldHeight))
        xField.placeholderString = "0 ~ \(screenW)"
        xField.delegate = self
        boxContent.addSubview(xField)
        xMaxLabel = NSTextField(labelWithString: "")
        xMaxLabel.frame = NSRect(x: fieldX + fieldWidth + 8, y: y + 2, width: 90, height: 18)
        xMaxLabel.font = NSFont.systemFont(ofSize: 10)
        xMaxLabel.textColor = .secondaryLabelColor
        xMaxLabel.isBordered = false
        xMaxLabel.isEditable = false
        boxContent.addSubview(xMaxLabel)
        y -= 30

        // Y field + yMaxLabel
        let yLbl = NSTextField(labelWithString: "Y:")
        yLbl.frame = NSRect(x: formX, y: y, width: labelWidth, height: fieldHeight)
        yLbl.alignment = .right
        yLbl.font = labelFont
        boxContent.addSubview(yLbl)
        yField = NSTextField(frame: NSRect(x: fieldX, y: y, width: fieldWidth, height: fieldHeight))
        yField.placeholderString = "0 ~ \(screenH)"
        yField.delegate = self
        boxContent.addSubview(yField)
        yMaxLabel = NSTextField(labelWithString: "")
        yMaxLabel.frame = NSRect(x: fieldX + fieldWidth + 8, y: y + 2, width: 90, height: 18)
        yMaxLabel.font = NSFont.systemFont(ofSize: 10)
        yMaxLabel.textColor = .secondaryLabelColor
        yMaxLabel.isBordered = false
        yMaxLabel.isEditable = false
        boxContent.addSubview(yMaxLabel)
        y -= 30

        // Center button — auto-calculates X/Y to center the window
        let centerBtn = NSButton(frame: NSRect(x: fieldX, y: y, width: 80, height: 24))
        centerBtn.title = "⊹ Center"
        centerBtn.bezelStyle = .rounded
        centerBtn.font = NSFont.systemFont(ofSize: 11)
        centerBtn.target = self
        centerBtn.action = #selector(centerButtonClicked)
        boxContent.addSubview(centerBtn)
        y -= 30

        // Info text
        let centerInfo = NSTextField(labelWithString: "※ Layout selection auto-calculates Width/Height/X/Y.")
        centerInfo.frame = NSRect(x: fieldX, y: y, width: 380, height: 16)
        centerInfo.font = NSFont.systemFont(ofSize: 10)
        centerInfo.textColor = .tertiaryLabelColor
        boxContent.addSubview(centerInfo)
        y -= 30

        // Minimap preview — centered below info text
        let minimapWidth: CGFloat = 150
        let minimapHeight: CGFloat = minimapWidth * (screen.frame.height / screen.frame.width)
        let minimapX = (boxWidth - 20 - minimapWidth) / 2
        minimapView = MinimapView(frame: NSRect(x: minimapX, y: y - minimapHeight, width: minimapWidth, height: minimapHeight))
        boxContent.addSubview(minimapView)

        // Bottom bar: background checkbox left, Save/Reload right
        backgroundCheckbox = NSButton(frame: NSRect(x: margin, y: margin + 28 + 8, width: 280, height: 20))
        backgroundCheckbox.setButtonType(.switch)
        backgroundCheckbox.title = "Run in Background (no Dock icon)"
        backgroundCheckbox.font = NSFont.systemFont(ofSize: 12)
        backgroundCheckbox.state = .on
        content.addSubview(backgroundCheckbox)

        saveBtn = NSButton(frame: NSRect(x: winWidth - margin - 80, y: margin, width: 80, height: 28))
        saveBtn.title = "Save"
        saveBtn.bezelStyle = .rounded
        saveBtn.target = self
        saveBtn.action = #selector(save)
        content.addSubview(saveBtn)

        let reloadBtn = NSButton(frame: NSRect(x: winWidth - margin - 80 - 8 - 80, y: margin, width: 80, height: 28))
        reloadBtn.title = "Reload"
        reloadBtn.bezelStyle = .rounded
        reloadBtn.target = self
        reloadBtn.action = #selector(reload)
        content.addSubview(reloadBtn)
    }

    func clearFields() {
        nameField.stringValue = ""
        urlField.stringValue = ""
        widthField.stringValue = ""
        heightField.stringValue = ""
        xField.stringValue = ""
        yField.stringValue = ""
        layoutPopup?.selectItem(at: 0)
        sizePopup?.selectItem(at: 0)
        updateLayoutButtonSelection(-1)
        updatePlaceholders()
        minimapView?.update(x: 0, y: 0, w: 0, h: 0, selected: false)
    }

    func controlTextDidChange(_ notification: Notification) {
        guard let field = notification.object as? NSTextField else { return }
        saveBtn?.isEnabled = true
        // Numeric-only validation for position/size fields
        if field === widthField || field === heightField || field === xField || field === yField {
            let filtered = field.stringValue.filter { $0.isNumber }
            if filtered != field.stringValue { field.stringValue = filtered }
        }
        // Skip preset resets when values are being set programmatically
        if isUpdatingFromPreset {
            updatePlaceholders()
            updateMinimap()
            return
        }
        if field === widthField || field === heightField {
            sizePopup?.selectItem(at: 0)
            updatePlaceholders()
            if layoutPopup.indexOfSelectedItem == 1 { // "Center"
                autoCenterXY()
            } else {
                layoutPopup.selectItem(at: 0) // "Custom"
                updateLayoutButtonSelection(-1)
                updateSizeFieldsEnabled()
            }
        } else if field === xField || field === yField {
            layoutPopup.selectItem(at: 0) // "Custom"
            updateLayoutButtonSelection(-1)
            updateSizeFieldsEnabled()
        }
        updateMinimap()
    }

    // Auto-fill X/Y to center the window on screen based on current width/height
    func autoCenterXY() {
        guard let screen = NSScreen.main else { return }
        let screenW = Int(screen.frame.width)
        let screenH = Int(screen.frame.height)
        if let w = Int(widthField.stringValue), w > 0 {
            xField.stringValue = "\((screenW - w) / 2)"
        }
        if let h = Int(heightField.stringValue), h > 0 {
            yField.stringValue = "\((screenH - h) / 2)"
        }
    }

    @objc func centerButtonClicked() {
        autoCenterXY()
        updatePlaceholders()
        updateMinimap()
        saveBtn?.isEnabled = true
    }

    @objc func layoutChanged(_ sender: NSPopUpButton) {
        saveBtn?.isEnabled = true
        guard let screen = NSScreen.main else { return }
        let screenW = Int(screen.frame.width)
        let screenH = Int(screen.frame.height)
        let idx = sender.indexOfSelectedItem
        updateLayoutButtonSelection(idx - 1)
        guard idx > 0 else { return } // "Custom" — do nothing

        isUpdatingFromPreset = true
        if idx == 1 { // "Center"
            let w = Int(widthField.stringValue) ?? 600
            let h = Int(heightField.stringValue) ?? 400
            if widthField.stringValue.isEmpty { widthField.stringValue = "600" }
            if heightField.stringValue.isEmpty { heightField.stringValue = "400" }
            xField.stringValue = "\((screenW - w) / 2)"
            yField.stringValue = "\((screenH - h) / 2)"
        } else {
            let presets: [(Int, Int, Int, Int)] = [
                (screenW/2, screenH, 0, 0),           // Left Half
                (screenW/2, screenH, screenW/2, 0),   // Right Half
                (screenW, screenH/2, 0, 0),           // Top Half
                (screenW, screenH/2, 0, screenH/2),   // Bottom Half
                (screenW/2, screenH/2, 0, 0),         // Top-Left
                (screenW/2, screenH/2, screenW/2, 0), // Top-Right
                (screenW/2, screenH/2, 0, screenH/2), // Bottom-Left
                (screenW/2, screenH/2, screenW/2, screenH/2), // Bottom-Right
            ]
            let p = presets[idx - 2]
            widthField.stringValue = "\(p.0)"
            heightField.stringValue = "\(p.1)"
            xField.stringValue = "\(p.2)"
            yField.stringValue = "\(p.3)"
        }
        isUpdatingFromPreset = false
        updatePlaceholders()
        updateMinimap()
        updateSizeFieldsEnabled()
    }

    func updateSizeFieldsEnabled() {
        let idx = layoutPopup.indexOfSelectedItem
        // Only Center (1) allows size editing
        let editable = idx == 0 || idx == 1
        let sizeEnabled = idx == 1
        widthField.isEditable = editable
        heightField.isEditable = editable
        sizePopup.isEnabled = sizeEnabled
        widthField.textColor = editable ? .labelColor : .secondaryLabelColor
        heightField.textColor = editable ? .labelColor : .secondaryLabelColor
    }

    @objc func sizeChanged(_ sender: NSPopUpButton) {
        saveBtn?.isEnabled = true
        let idx = sender.indexOfSelectedItem
        guard idx > 0 else { return } // "Custom" — do nothing
        let sizes: [(Int, Int)] = [(400,200), (600,300), (800,500), (1000,700), (1200,800), (1000,400), (500,800), (1400,900)]
        let (w, h) = sizes[idx - 1]
        isUpdatingFromPreset = true
        widthField.stringValue = "\(w)"
        heightField.stringValue = "\(h)"
        isUpdatingFromPreset = false
        updatePlaceholders()
        if layoutPopup.indexOfSelectedItem == 1 { // "Center"
            autoCenterXY()
        }
        updateMinimap()
    }

    func layoutButtonClicked(_ index: Int) {
        // index 0-8 maps to layoutPopup index 1-9
        layoutPopup.selectItem(at: index + 1)
        layoutChanged(layoutPopup)
    }

    func updateLayoutButtonSelection(_ index: Int) {
        for (i, btn) in layoutButtons.enumerated() {
            btn.isSelected = (i == index)
        }
    }

    // Updates placeholder text based on current width/height values
    func updatePlaceholders() {
        guard let screen = NSScreen.main else { return }
        let screenW = Int(screen.frame.width)
        let screenH = Int(screen.frame.height)
        if let w = Int(widthField.stringValue), w > 0 {
            xField.placeholderString = "0 ~ \(screenW - w)"
            xMaxLabel?.stringValue = "max: \(screenW - w)"
        } else {
            xField.placeholderString = "0 ~ \(screenW)"
            xMaxLabel?.stringValue = "max: \(screenW)"
        }
        if let h = Int(heightField.stringValue), h > 0 {
            yField.placeholderString = "0 ~ \(screenH - h)"
            yMaxLabel?.stringValue = "max: \(screenH - h)"
        } else {
            yField.placeholderString = "0 ~ \(screenH)"
            yMaxLabel?.stringValue = "max: \(screenH)"
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int { sites.count }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        sites[row].name
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        guard row >= 0 else { return }

        // Check for unsaved changes in previous selection
        if previousSelectedRow >= 0 && previousSelectedRow < sites.count {
            let prev = sites[previousSelectedRow]
            if nameField.stringValue != prev.name ||
               urlField.stringValue != prev.url ||
               widthField.stringValue != "\(prev.width)" ||
               heightField.stringValue != "\(prev.height)" ||
               xField.stringValue != "\(prev.x)" ||
               yField.stringValue != "\(prev.y)" {
                let alert = NSAlert()
                alert.messageText = "You have unsaved changes. Discard?"
                alert.addButton(withTitle: "Discard")
                alert.addButton(withTitle: "Cancel")
                if alert.runModal() != .alertFirstButtonReturn {
                    tableView.selectRowIndexes(IndexSet(integer: previousSelectedRow), byExtendingSelection: false)
                    return
                }
            }
        }

        let s = sites[row]
        nameField.stringValue = s.name
        urlField.stringValue = s.url
        widthField.stringValue = "\(s.width)"
        heightField.stringValue = "\(s.height)"
        xField.stringValue = "\(s.x)"
        yField.stringValue = "\(s.y)"
        layoutPopup.selectItem(at: 0)
        sizePopup.selectItem(at: 0)
        updateLayoutButtonSelection(-1)
        updateSizeFieldsEnabled()
        updatePlaceholders()
        updateMinimap()
        previousSelectedRow = row
    }

    @objc func addSite() {
        sites.append(Site(name: "New Site", url: "https://", width: Defaults.defaultWidth, height: Defaults.defaultHeight, x: Defaults.defaultX, y: Defaults.defaultY))
        tableView.reloadData()
        tableView.selectRowIndexes(IndexSet(integer: sites.count - 1), byExtendingSelection: false)
    }

    @objc func removeSite() {
        let row = tableView.selectedRow
        guard row >= 0 else { return }
        let alert = NSAlert()
        alert.messageText = "Are you sure you want to delete?"
        alert.informativeText = "This will remove \"\(sites[row].name)\"."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        sites.remove(at: row)
        tableView.reloadData()
        clearFields()
        previousSelectedRow = -1
    }

    @objc func moveSiteUp() {
        let row = tableView.selectedRow
        guard row > 0 else { return }
        sites.swapAt(row, row - 1)
        tableView.reloadData()
        previousSelectedRow = row - 1
        tableView.selectRowIndexes(IndexSet(integer: row - 1), byExtendingSelection: false)
    }

    @objc func moveSiteDown() {
        let row = tableView.selectedRow
        guard row >= 0, row < sites.count - 1 else { return }
        sites.swapAt(row, row + 1)
        tableView.reloadData()
        previousSelectedRow = row + 1
        tableView.selectRowIndexes(IndexSet(integer: row + 1), byExtendingSelection: false)
    }

    func updateMinimap() {
        let selected = tableView.selectedRow >= 0 || !widthField.stringValue.isEmpty
        let w = CGFloat(Int(widthField.stringValue) ?? 0)
        let h = CGFloat(Int(heightField.stringValue) ?? 0)
        let x = CGFloat(Int(xField.stringValue) ?? 0)
        let y = CGFloat(Int(yField.stringValue) ?? 0)
        minimapView?.update(x: x, y: y, w: w, h: h, selected: selected)
    }

    // MARK: Save — validates URL, persists config, and hides window
    @objc func save() {
        let row = tableView.selectedRow
        if row >= 0 {
            // Empty name validation
            if nameField.stringValue.trimmingCharacters(in: .whitespaces).isEmpty {
                let alert = NSAlert()
                alert.messageText = "Please enter a name."
                alert.alertStyle = .warning
                alert.runModal()
                return
            }

            // Basic URL validation: must not be empty and must start with "http"
            let url = urlField.stringValue.trimmingCharacters(in: .whitespaces)
            if url.isEmpty || !url.hasPrefix("http") {
                let alert = NSAlert()
                alert.messageText = "Invalid URL"
                alert.informativeText = "URL must start with \"http\" or \"https\"."
                alert.alertStyle = .warning
                alert.runModal()
                return
            }

            guard let screen = NSScreen.main else { return }
            let screenW = Int(screen.frame.width)
            let screenH = Int(screen.frame.height)
            var w = Int(widthField.stringValue) ?? Defaults.defaultWidth
            var h = Int(heightField.stringValue) ?? Defaults.defaultHeight
            w = min(w, screenW)
            h = min(h, screenH)
            var x = Int(xField.stringValue) ?? Defaults.defaultX
            var y = Int(yField.stringValue) ?? Defaults.defaultY
            x = max(0, min(x, screenW - w))
            y = max(0, min(y, screenH - h))
            sites[row] = Site(name: nameField.stringValue, url: url,
                              width: w, height: h, x: x, y: y)
        }
        onSave?(sites, backgroundCheckbox.state == .on)
        saveBtn.isEnabled = false
    }

    @objc func reload() {
        onReload?()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if hasUnsavedChanges() {
            let alert = NSAlert()
            alert.messageText = "You have unsaved changes."
            alert.informativeText = "Changes will be lost if you close."
            alert.addButton(withTitle: "Close")
            alert.addButton(withTitle: "Cancel")
            return alert.runModal() == .alertFirstButtonReturn
        }
        return true
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(runInBackground ? .accessory : .regular)
    }

    private func hasUnsavedChanges() -> Bool {
        let row = tableView.selectedRow
        guard row >= 0 && row < sites.count else { return false }
        let s = sites[row]
        return nameField.stringValue != s.name ||
               urlField.stringValue != s.url ||
               widthField.stringValue != "\(s.width)" ||
               heightField.stringValue != "\(s.height)" ||
               xField.stringValue != "\(s.x)" ||
               yField.stringValue != "\(s.y)"
    }
}

// MARK: - App Delegate — menu bar app lifecycle

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var config: Config = Config(sites: [])
    let configPath = NSString(string: "~/.quickaccess.json").expandingTildeInPath
    let settingsController = SettingsWindowController()

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        copyDefaultConfigIfNeeded()
        loadConfig()
        NSApp.setActivationPolicy(config.runInBackground ? .accessory : .regular)

        statusItem = NSStatusBar.system.statusItem(withLength: 28)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "QuickAccess")
        }
        buildMenu()
    }

    // MARK: Config handling — copies default config on first launch
    func copyDefaultConfigIfNeeded() {
        if !FileManager.default.fileExists(atPath: configPath) {
            if let bundledPath = Bundle.main.path(forResource: "quickaccess-default", ofType: "json") {
                do {
                    try FileManager.default.copyItem(atPath: bundledPath, toPath: configPath)
                } catch {
                    NSLog("[QuickAccess] Failed to copy default config: %@", error.localizedDescription)
                }
            } else {
                let defaultJSON = """
                {
                  "sites": [
                    {"name": "Google", "url": "https://www.google.com/", "width": 600, "height": 400, "x": 100, "y": 100},
                    {"name": "GitHub", "url": "https://github.com/", "width": 800, "height": 600, "x": 200, "y": 100}
                  ]
                }
                """
                do {
                    try defaultJSON.write(toFile: configPath, atomically: true, encoding: .utf8)
                } catch {
                    NSLog("[QuickAccess] Failed to write default config: %@", error.localizedDescription)
                }
            }
        }
    }

    func loadConfig() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)) else {
            NSLog("[QuickAccess] Failed to read config file at %@", configPath)
            return
        }
        do {
            config = try JSONDecoder().decode(Config.self, from: data)
        } catch {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Cannot read config file. Using defaults."
                alert.alertStyle = .warning
                alert.runModal()
            }
            config = Config(sites: [
                Site(name: "Google", url: "https://www.google.com/", width: 600, height: 400, x: Defaults.defaultX, y: Defaults.defaultY),
                Site(name: "GitHub", url: "https://github.com/", width: Defaults.defaultWidth, height: Defaults.defaultHeight, x: Defaults.defaultX, y: Defaults.defaultY)
            ])
        }
    }

    func buildMenu() {
        let menu = NSMenu()
        for site in config.sites {
            let item = NSMenuItem(title: site.name, action: #selector(openSite(_:)), keyEquivalent: "")
            item.representedObject = site
            item.target = self
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: "")
        settings.target = self
        menu.addItem(settings)
        let about = NSMenuItem(title: "About QuickAccess", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
    }

    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "QuickAccess"
        alert.informativeText = "Version \(Defaults.appVersion)\n\nMade by Mingyu Park\nuqwe00@gmail.com\nbrianmg@naver.com"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
        NSApp.setActivationPolicy(config.runInBackground ? .accessory : .regular)
    }

    // MARK: Site opening logic — launches Chrome in app mode, then repositions via AppleScript
    @objc func openSite(_ sender: NSMenuItem) {
        guard let site = sender.representedObject as? Site else { return }

        // Fix #6: Check if Chrome is installed
        if !FileManager.default.fileExists(atPath: "/Applications/Google Chrome.app") {
            let alert = NSAlert()
            alert.messageText = "Google Chrome is not installed."
            alert.alertStyle = .warning
            alert.runModal()
            return
        }

        // Fix #1: Escape all AppleScript-special characters to prevent injection
        let rawDomain = URL(string: site.url)?.host ?? ""
        // Strict validation: only allow safe hostname characters
        let domainRegex = try! NSRegularExpression(pattern: "^[a-zA-Z0-9._-]+$")
        guard !rawDomain.isEmpty,
              domainRegex.firstMatch(in: rawDomain, range: NSRange(rawDomain.startIndex..., in: rawDomain)) != nil else {
            return
        }
        let domain = rawDomain

        // Validate bounds are numeric
        let bx = site.x
        let by = site.y
        let bw = site.width
        let bh = site.height
        let bounds = "\(bx), \(by), \(bx + bw), \(by + bh)"

        let retries = Defaults.resizeRetries
        let retryInterval = Defaults.retryInterval
        let script = """
        tell application "Google Chrome"
          repeat \(retries) times
            repeat with w in windows
              set tabUrl to URL of active tab of w
              if tabUrl contains "\(domain)" then
                set bounds of w to {\(bounds)}
                return
              end if
            end repeat
            delay \(retryInterval)
          end repeat
        end tell
        """

        // Detect if Chrome is already running for delay calculation
        let chromeRunning = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "com.google.Chrome" }
        let delay = chromeRunning ? Defaults.resizeDelay : Defaults.coldStartDelay

        // Open Chrome in app mode using modern Process API
        let openTask = Process()
        openTask.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        openTask.arguments = ["-na", "Google Chrome", "--args", "--app=\(site.url)"]
        do {
            try openTask.run()
        } catch {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Failed to launch Chrome."
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .critical
                alert.runModal()
            }
            return
        }

        // Reposition the window via osascript after a short delay
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
            let scriptTask = Process()
            scriptTask.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            scriptTask.arguments = ["-e", script]
            do {
                try scriptTask.run()
                scriptTask.waitUntilExit()
                if scriptTask.terminationStatus != 0 {
                    NSLog("[QuickAccess] osascript exited with status %d", scriptTask.terminationStatus)
                }
            } catch {
                NSLog("[QuickAccess] Failed to launch osascript: %@", error.localizedDescription)
            }
        }
    }

    @objc func openSettings() {
        settingsController.onReload = { [weak self] in
            self?.reloadConfig()
            if let sites = self?.config.sites {
                self?.settingsController.sites = sites
                self?.settingsController.tableView.reloadData()
                self?.settingsController.clearFields()
            }
        }
        settingsController.showWindow(sites: config.sites, runInBackground: config.runInBackground) { [weak self] newSites, runInBackground in
            guard let self = self else { return }
            self.config = Config(runInBackground: runInBackground, sites: newSites)
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            if let data = try? encoder.encode(self.config) {
                do {
                    try data.write(to: URL(fileURLWithPath: self.configPath), options: .atomic)
                } catch {
                    let alert = NSAlert()
                    alert.messageText = "Failed to save settings."
                    alert.alertStyle = .warning
                    alert.runModal()
                }
            }
            self.buildMenu()
            NSApp.setActivationPolicy(runInBackground ? .accessory : .regular)
        }
    }

    @objc func reloadConfig() {
        loadConfig()
        buildMenu()
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}

// MARK: - App entry point
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// Enable standard Edit menu for copy/paste/cut in text fields
let mainMenu = NSMenu()
let editMenuItem = NSMenuItem()
let editMenu = NSMenu(title: "Edit")
editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
editMenuItem.submenu = editMenu
mainMenu.addItem(editMenuItem)
app.mainMenu = mainMenu

app.run()
