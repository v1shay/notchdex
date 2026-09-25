import AppKit

struct NotchGeometry {
    let screen: NSScreen
    let hardwareWidth: CGFloat
    let hardwareHeight: CGFloat
    let expandedWidth: CGFloat
    let expandedHeight: CGFloat

    static func current(sizeIndex: Int = 3) -> NotchGeometry {
        let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens[0]
        let safeTop = max(screen.safeAreaInsets.top, 24)

        var width: CGFloat = 210
        if #available(macOS 12.0, *),
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            let measured = screen.frame.width - left.width - right.width
            if measured > 80 && measured < 420 { width = measured }
        }

        let presets: [(width: CGFloat, height: CGFloat)] = [
            (500, 265),
            (570, 325),
            (640, 390),
            (740, 470)
        ]
        let preset = presets[min(max(sizeIndex, 1), 4) - 1]

        return NotchGeometry(
            screen: screen,
            hardwareWidth: width,
            hardwareHeight: safeTop,
            expandedWidth: min(max(preset.width, width + 270), screen.frame.width - 40),
            expandedHeight: min(preset.height, screen.frame.height * 0.54)
        )
    }

    var windowFrame: NSRect {
        NSRect(
            x: screen.frame.midX - expandedWidth / 2,
            y: screen.frame.maxY - expandedHeight,
            width: expandedWidth,
            height: expandedHeight
        )
    }

    var collapsedFrame: NSRect {
        NSRect(
            x: screen.frame.midX - hardwareWidth / 2,
            y: screen.frame.maxY - hardwareHeight,
            width: hardwareWidth,
            height: hardwareHeight
        )
    }
}
