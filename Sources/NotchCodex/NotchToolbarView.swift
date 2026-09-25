import AppKit

final class NotchToolbarView: NSView {
    var onSizeSelected: ((Int) -> Void)?
    var onTerminalSelected: ((Int) -> Void)?
    var geometry: NotchGeometry { didSet { needsLayout = true } }

    private let sizeButtons: [SizeSelectorButton]
    private let terminalButtons: [TerminalSelectorButton]
    private(set) var selectedSize = 3
    private(set) var selectedTerminal = 0

    init(frame frameRect: NSRect, geometry: NotchGeometry) {
        self.geometry = geometry
        sizeButtons = (1...4).map { SizeSelectorButton(number: $0) }

        let colors: [NSColor] = [
            NSColor(calibratedRed: 0.27, green: 0.82, blue: 1, alpha: 1),
            NSColor(calibratedRed: 0.68, green: 0.46, blue: 1, alpha: 1),
            NSColor(calibratedRed: 1, green: 0.49, blue: 0.27, alpha: 1),
            NSColor(calibratedRed: 0.30, green: 0.88, blue: 0.57, alpha: 1)
        ]
        let iconURL = Bundle.main.resourceURL?.appendingPathComponent("codex.svg")
        let sourceImage = iconURL.flatMap(NSImage.init(contentsOf:))
        sourceImage?.isTemplate = true
        sourceImage?.size = NSSize(width: 20, height: 20)
        terminalButtons = colors.enumerated().map {
            TerminalSelectorButton(index: $0.offset, color: $0.element, image: sourceImage)
        }

        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        for button in sizeButtons {
            button.handler = { [weak self, weak button] in
                guard let self, let button else { return }
                self.selectSize(button.number)
                self.onSizeSelected?(button.number)
            }
            addSubview(button)
        }
        for button in terminalButtons {
            button.handler = { [weak self, weak button] in
                guard let self, let button else { return }
                self.selectTerminal(button.index)
                self.onTerminalSelected?(button.index)
            }
            addSubview(button)
        }
        refreshSelection()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var isFlipped: Bool { true }

    override func layout() {
        super.layout()
        let buttonSize: CGFloat = 24
        let gap: CGFloat = 4
        let groupWidth = buttonSize * 4 + gap * 3
        let y = max(3, (geometry.hardwareHeight - buttonSize) / 2)
        let notchLeft = bounds.midX - geometry.hardwareWidth / 2
        let notchRight = bounds.midX + geometry.hardwareWidth / 2

        let outerInset: CGFloat = 8
        let leftWingWidth = notchLeft - outerInset
        let leftStart = outerInset + (leftWingWidth - groupWidth) / 2
        for (index, button) in sizeButtons.enumerated() {
            button.frame = NSRect(x: leftStart + CGFloat(index) * (buttonSize + gap), y: y, width: buttonSize, height: buttonSize)
        }

        let rightWingWidth = bounds.width - outerInset - notchRight
        let rightStart = notchRight + (rightWingWidth - groupWidth) / 2
        for (index, button) in terminalButtons.enumerated() {
            button.frame = NSRect(x: rightStart + CGFloat(index) * (buttonSize + gap), y: y, width: buttonSize, height: buttonSize)
        }
    }

    func selectSize(_ number: Int) {
        selectedSize = min(max(number, 1), 4)
        refreshSelection()
    }

    func selectTerminal(_ index: Int) {
        selectedTerminal = min(max(index, 0), 3)
        refreshSelection()
    }

    private func refreshSelection() {
        for button in sizeButtons { button.isCurrent = button.number == selectedSize }
        for button in terminalButtons { button.isCurrent = button.index == selectedTerminal }
    }
}

private class ToolbarActionButton: NSButton {
    var handler: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isBordered = false
        setButtonType(.momentaryChange)
        target = self
        action = #selector(trigger)
        focusRingType = .none
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func trigger() { handler?() }
}

private final class SizeSelectorButton: ToolbarActionButton {
    let number: Int
    var isCurrent = false { didSet { updateAppearance() } }

    init(number: Int) {
        self.number = number
        super.init(frame: .zero)
        toolTip = "Panel size \(number)"
        updateAppearance()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func updateAppearance() {
        let color = NSColor.white.withAlphaComponent(isCurrent ? 0.98 : 0.50)
        attributedTitle = NSAttributedString(
            string: "\(number)",
            attributes: [
                .foregroundColor: color,
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: isCurrent ? .semibold : .regular)
            ]
        )
        needsDisplay = true
    }
}

private final class TerminalSelectorButton: ToolbarActionButton {
    let index: Int
    private let accent: NSColor
    var isCurrent = false { didSet { updateAppearance() } }

    init(index: Int, color: NSColor, image: NSImage?) {
        self.index = index
        self.accent = color
        super.init(frame: .zero)
        self.image = image
        imagePosition = .imageOnly
        imageScaling = .scaleNone
        toolTip = "Codex terminal \(index + 1)"
        wantsLayer = true
        updateAppearance()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func updateAppearance() {
        contentTintColor = accent.withAlphaComponent(isCurrent ? 1 : 0.65)
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.borderWidth = 0
        alphaValue = isCurrent ? 1 : 0.72
        needsDisplay = true
    }
}
