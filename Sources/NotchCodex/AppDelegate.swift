import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: NotchWindowController?
    private var gestures: GestureController?
    private var statusItem: NSStatusItem?

    private var appearanceColor = NSColor.black
    private var transparencyEnabled = false
    private var appearanceOpacity: CGFloat = 0.70
    private var colorItems: [NSMenuItem] = []
    private var opacityItems: [NSMenuItem] = []
    private weak var customColorItem: NSMenuItem?
    private weak var transparencyItem: NSMenuItem?

    private let colorKey = "terminalAppearanceColor"
    private let transparentKey = "terminalAppearanceTransparent"
    private let opacityKey = "terminalAppearanceOpacity"

    func applicationDidFinishLaunching(_ notification: Notification) {
        loadAppearance()
        let controller = NotchWindowController()
        controller.setAppearance(color: appearanceColor, opacity: effectiveOpacity)
        self.controller = controller
        self.gestures = GestureController(
            isOpen: { [weak controller] in controller?.isExpanded ?? false },
            toggle: { [weak controller] in controller?.toggle() },
            close: { [weak controller] in controller?.collapse() },
            typeText: { [weak controller] text in controller?.type(text) },
            beginDictation: { [weak controller] in controller?.beginDictation() },
            endDictation: { [weak controller] in controller?.endDictation() }
        )
        installStatusItem()
        controller.showCollapsed()
    }

    func applicationWillTerminate(_ notification: Notification) {
        gestures?.stop()
    }

    private var effectiveOpacity: CGFloat { transparencyEnabled ? appearanceOpacity : 1 }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: "Notch Codex")
        item.button?.toolTip = "Notch Codex"

        let menu = NSMenu()
        menu.addItem(menuItem("Open / Close Notch Codex", action: #selector(toggleNotch)))
        menu.addItem(menuItem("Enable Accessibility…", action: #selector(openAccessibility)))
        menu.addItem(.separator())

        let appearanceRoot = NSMenuItem(title: "Terminal Appearance", action: nil, keyEquivalent: "")
        let appearanceMenu = NSMenu(title: "Terminal Appearance")
        let presets: [(String, Int)] = [
            ("Black", 0),
            ("Graphite", 1),
            ("Midnight Blue", 2),
            ("Forest", 3),
            ("Burgundy", 4)
        ]
        colorItems = presets.map { title, tag in
            let item = menuItem(title, action: #selector(selectPresetColor(_:)))
            item.tag = tag
            appearanceMenu.addItem(item)
            return item
        }
        let custom = menuItem("Choose Color…", action: #selector(chooseColor))
        customColorItem = custom
        appearanceMenu.addItem(custom)
        appearanceMenu.addItem(.separator())

        let transparent = menuItem("Use Transparency", action: #selector(toggleTransparency(_:)))
        transparencyItem = transparent
        appearanceMenu.addItem(transparent)

        let opacityRoot = NSMenuItem(title: "Opacity", action: nil, keyEquivalent: "")
        let opacityMenu = NSMenu(title: "Opacity")
        opacityItems = [25, 40, 55, 70, 85, 95].map { percent in
            let item = menuItem("\(percent)%", action: #selector(selectOpacity(_:)))
            item.tag = percent
            opacityMenu.addItem(item)
            return item
        }
        opacityRoot.submenu = opacityMenu
        appearanceMenu.addItem(opacityRoot)
        appearanceRoot.submenu = appearanceMenu
        menu.addItem(appearanceRoot)

        menu.addItem(.separator())
        menu.addItem(menuItem("Quit Notch Codex", action: #selector(quit), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
        refreshAppearanceMenu()
    }

    private func menuItem(_ title: String, action: Selector, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    @objc private func toggleNotch() { controller?.toggle() }

    @objc private func openAccessibility() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func selectPresetColor(_ sender: NSMenuItem) {
        appearanceColor = presetColor(sender.tag)
        saveAppearance()
        applyAppearance()
    }

    @objc private func chooseColor() {
        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        panel.color = appearanceColor
        panel.setTarget(self)
        panel.setAction(#selector(colorPanelChanged(_:)))
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func colorPanelChanged(_ sender: NSColorPanel) {
        appearanceColor = sender.color.usingColorSpace(.deviceRGB) ?? sender.color
        saveAppearance()
        applyAppearance()
    }

    @objc private func toggleTransparency(_ sender: NSMenuItem) {
        transparencyEnabled.toggle()
        saveAppearance()
        applyAppearance()
    }

    @objc private func selectOpacity(_ sender: NSMenuItem) {
        appearanceOpacity = CGFloat(sender.tag) / 100
        transparencyEnabled = true
        saveAppearance()
        applyAppearance()
    }

    private func applyAppearance() {
        controller?.setAppearance(color: appearanceColor, opacity: effectiveOpacity)
        refreshAppearanceMenu()
    }

    private func presetColor(_ tag: Int) -> NSColor {
        switch tag {
        case 1: return NSColor(calibratedRed: 0.075, green: 0.082, blue: 0.095, alpha: 1)
        case 2: return NSColor(calibratedRed: 0.025, green: 0.070, blue: 0.125, alpha: 1)
        case 3: return NSColor(calibratedRed: 0.025, green: 0.105, blue: 0.080, alpha: 1)
        case 4: return NSColor(calibratedRed: 0.145, green: 0.035, blue: 0.055, alpha: 1)
        default: return .black
        }
    }

    private func refreshAppearanceMenu() {
        let matchingTag = colorItems.first(where: { colorsMatch(appearanceColor, presetColor($0.tag)) })?.tag
        for item in colorItems { item.state = item.tag == matchingTag ? .on : .off }
        customColorItem?.state = matchingTag == nil ? .on : .off
        transparencyItem?.state = transparencyEnabled ? .on : .off
        for item in opacityItems {
            item.state = item.tag == Int((appearanceOpacity * 100).rounded()) ? .on : .off
        }
    }

    private func colorsMatch(_ lhs: NSColor, _ rhs: NSColor) -> Bool {
        guard let a = lhs.usingColorSpace(.deviceRGB), let b = rhs.usingColorSpace(.deviceRGB) else { return false }
        return abs(a.redComponent - b.redComponent) < 0.005
            && abs(a.greenComponent - b.greenComponent) < 0.005
            && abs(a.blueComponent - b.blueComponent) < 0.005
    }

    private func loadAppearance() {
        let defaults = UserDefaults.standard
        if let components = defaults.array(forKey: colorKey) as? [Double], components.count == 3 {
            appearanceColor = NSColor(
                calibratedRed: CGFloat(components[0]),
                green: CGFloat(components[1]),
                blue: CGFloat(components[2]),
                alpha: 1
            )
        }
        transparencyEnabled = defaults.bool(forKey: transparentKey)
        let savedOpacity = defaults.double(forKey: opacityKey)
        if savedOpacity >= 0.12 { appearanceOpacity = CGFloat(savedOpacity) }
    }

    private func saveAppearance() {
        let color = appearanceColor.usingColorSpace(.deviceRGB) ?? appearanceColor
        UserDefaults.standard.set(
            [Double(color.redComponent), Double(color.greenComponent), Double(color.blueComponent)],
            forKey: colorKey
        )
        UserDefaults.standard.set(transparencyEnabled, forKey: transparentKey)
        UserDefaults.standard.set(Double(appearanceOpacity), forKey: opacityKey)
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
