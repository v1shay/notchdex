import AppKit
import SwiftTerm
import UniformTypeIdentifiers

final class TerminalContainerView: NSView {
    let terminal = LocalProcessTerminalView(frame: .zero)
    private var didLaunch = false
    private var appearanceColor = NSColor.black
    private var appearanceOpacity: CGFloat = 1

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.masksToBounds = true
        registerForDraggedTypes([.fileURL])

        terminal.translatesAutoresizingMaskIntoConstraints = false
        terminal.nativeBackgroundColor = .black
        terminal.nativeForegroundColor = NSColor(calibratedWhite: 0.92, alpha: 1)
        terminal.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        addSubview(terminal)

        NSLayoutConstraint.activate([
            terminal.leadingAnchor.constraint(equalTo: leadingAnchor),
            terminal.trailingAnchor.constraint(equalTo: trailingAnchor),
            terminal.topAnchor.constraint(equalTo: topAnchor),
            terminal.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        droppedImageURL(from: sender) == nil ? [] : .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        droppedImageURL(from: sender) == nil ? [] : .copy
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        droppedImageURL(from: sender) != nil
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let url = droppedImageURL(from: sender) else { return false }
        focus()
        send(url.path)
        return true
    }

    func launchIfNeeded() {
        guard !didLaunch else { return }
        didLaunch = true
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let command = "if command -v codex >/dev/null 2>&1; then exec codex; else printf '\\n  Codex CLI was not found. Install it, then restart Notch Codex.\\n\\n'; exec \(shell) -l; fi"
        terminal.startProcess(
            executable: shell,
            args: ["-l", "-c", command],
            environment: inheritedEnvironment(),
            execName: nil,
            currentDirectory: FileManager.default.homeDirectoryForCurrentUser.path
        )
    }

    func focus() {
        window?.makeFirstResponder(terminal)
    }

    func send(_ text: String) {
        let bytes = Array(text.utf8)
        terminal.process.send(data: bytes[...])
    }

    func setListening(_ listening: Bool) {
        applyAppearance()
    }

    func setAppearance(color: NSColor, opacity: CGFloat) {
        appearanceColor = color
        appearanceOpacity = min(max(opacity, 0.12), 1)
        applyAppearance()
    }

    private func applyAppearance() {
        let background = appearanceColor.withAlphaComponent(appearanceOpacity)
        layer?.backgroundColor = background.cgColor
        terminal.nativeBackgroundColor = background
        terminal.backgroundOpacity = appearanceOpacity
        terminal.needsDisplay = true
    }

    private func droppedImageURL(from draggingInfo: NSDraggingInfo) -> URL? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]
        guard let items = draggingInfo.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: options
        ) as? [NSURL] else { return nil }

        return items
            .map { $0 as URL }
            .first { url in
                guard url.isFileURL,
                      let type = UTType(filenameExtension: url.pathExtension) else { return false }
                return type.conforms(to: .image)
            }
    }

    private func inheritedEnvironment() -> [String] {
        var env = ProcessInfo.processInfo.environment
        let common = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"]
        let current = env["PATH"]?.split(separator: ":").map(String.init) ?? []
        env["PATH"] = (current + common).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }.joined(separator: ":")
        env["TERM"] = "xterm-256color"
        env["COLORTERM"] = "truecolor"
        return env.map { "\($0.key)=\($0.value)" }
    }
}
