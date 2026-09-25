import AppKit

final class NotchWindowController: NSWindowController {
    private var selectedSize = 3
    private var activeTerminalIndex = 0
    private var appearanceColor = NSColor.black
    private var appearanceOpacity: CGFloat = 1
    private var geometry = NotchGeometry.current(sizeIndex: 3)
    private let root: NotchShapeView
    private let toolbar: NotchToolbarView
    private var terminals: [TerminalContainerView?] = Array(repeating: nil, count: 4)
    private let dictation = VoiceDictationController()
    private(set) var isExpanded = false

    private var activeTerminal: TerminalContainerView? { terminals[activeTerminalIndex] }

    init() {
        root = NotchShapeView(frame: geometry.windowFrame, geometry: geometry)
        toolbar = NotchToolbarView(frame: .zero, geometry: geometry)
        let window = KeyablePanel(
            contentRect: geometry.windowFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)

        window.level = .statusBar
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.hidesOnDeactivate = false
        window.isMovable = false
        window.contentView = root
        root.autoresizingMask = [.width, .height]
        window.ignoresMouseEvents = true

        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.alphaValue = 0
        toolbar.isHidden = true
        root.addSubview(toolbar)
        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            toolbar.topAnchor.constraint(equalTo: root.topAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: geometry.hardwareHeight)
        ])

        toolbar.onSizeSelected = { [weak self] index in self?.selectSize(index) }
        toolbar.onTerminalSelected = { [weak self] index in self?.selectTerminal(index) }
        dictation.onStateChange = { [weak self] listening in self?.activeTerminal?.setListening(listening) }
        dictation.onTranscript = { [weak self] text in self?.activeTerminal?.send(text) }
        root.onClick = { [weak self] in self?.toggle() }

        _ = createTerminal(at: 0)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func showCollapsed() {
        positionOnCurrentScreen()
        window?.orderFrontRegardless()
        if CommandLine.arguments.contains("--expanded") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in self?.expand() }
        }
    }

    func toggle() { isExpanded ? collapse() : expand() }

    func expand() {
        guard !isExpanded else { return }
        isExpanded = true
        window?.ignoresMouseEvents = false
        geometry = .current(sizeIndex: selectedSize)
        root.geometry = geometry
        toolbar.geometry = geometry
        window?.setFrame(geometry.windowFrame, display: true)
        root.frame = NSRect(origin: .zero, size: geometry.windowFrame.size)

        let terminal = createTerminal(at: activeTerminalIndex)
        terminal.isHidden = false
        toolbar.isHidden = false
        root.setExpanded(true)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        terminal.launchIfNeeded()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.28
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            terminal.animator().alphaValue = 1
            toolbar.animator().alphaValue = 1
        } completionHandler: { [weak terminal] in terminal?.focus() }
    }

    func collapse() {
        guard isExpanded else { return }
        isExpanded = false
        dictation.end()
        let terminal = activeTerminal
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            terminal?.animator().alphaValue = 0
            toolbar.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            terminal?.isHidden = true
            self?.toolbar.isHidden = true
            self?.root.setExpanded(false)
            self?.window?.resignKey()
            self?.window?.ignoresMouseEvents = true
        }
    }

    func type(_ text: String) { activeTerminal?.send(text) }
    func beginDictation() { dictation.begin() }
    func endDictation() { dictation.end() }

    func setAppearance(color: NSColor, opacity: CGFloat) {
        appearanceColor = color
        appearanceOpacity = opacity
        root.setAppearance(color: color, opacity: opacity)
        for terminal in terminals.compactMap({ $0 }) {
            terminal.setAppearance(color: color, opacity: opacity)
        }
    }

    private func createTerminal(at index: Int) -> TerminalContainerView {
        if let existing = terminals[index] { return existing }

        let terminal = TerminalContainerView(frame: .zero)
        terminal.translatesAutoresizingMaskIntoConstraints = false
        terminal.alphaValue = index == activeTerminalIndex && isExpanded ? 1 : 0
        terminal.isHidden = !(index == activeTerminalIndex && isExpanded)
        root.addSubview(terminal, positioned: .below, relativeTo: toolbar)
        NSLayoutConstraint.activate([
            terminal.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 22),
            terminal.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -22),
            terminal.topAnchor.constraint(equalTo: root.topAnchor, constant: geometry.hardwareHeight + 12),
            terminal.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -18)
        ])
        terminals[index] = terminal
        terminal.setAppearance(color: appearanceColor, opacity: appearanceOpacity)
        return terminal
    }

    private func selectTerminal(_ index: Int) {
        guard index != activeTerminalIndex else {
            activeTerminal?.focus()
            return
        }
        dictation.end()
        let previous = activeTerminal
        activeTerminalIndex = index
        toolbar.selectTerminal(index)
        let next = createTerminal(at: index)
        next.alphaValue = 0
        next.isHidden = false
        next.launchIfNeeded()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.20
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            previous?.animator().alphaValue = 0
            next.animator().alphaValue = 1
        } completionHandler: {
            previous?.isHidden = true
            next.focus()
        }
    }

    private func selectSize(_ index: Int) {
        guard index != selectedSize else { return }
        selectedSize = index
        toolbar.selectSize(index)
        geometry = .current(sizeIndex: index)
        root.geometry = geometry
        toolbar.geometry = geometry

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.38
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 0.82, 0.26, 1)
            window?.animator().setFrame(geometry.windowFrame, display: true)
        } completionHandler: { [weak self] in self?.activeTerminal?.focus() }
    }

    @objc private func screenChanged() { positionOnCurrentScreen() }

    private func positionOnCurrentScreen() {
        geometry = .current(sizeIndex: selectedSize)
        root.geometry = geometry
        toolbar.geometry = geometry
        window?.setFrame(geometry.windowFrame, display: true)
        root.frame = NSRect(origin: .zero, size: geometry.windowFrame.size)
    }
}

private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
