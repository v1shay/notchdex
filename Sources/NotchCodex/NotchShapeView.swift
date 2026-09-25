import AppKit
import QuartzCore

/// A compact, symmetric panel that grows directly from the hardware notch.
final class NotchShapeView: NSView {
    private let shapeLayer = CAShapeLayer()
    private let glassGradient = CAGradientLayer()
    private let glassMask = CAShapeLayer()
    private let beamGlow = CAShapeLayer()
    private let beamCore = CAShapeLayer()

    private(set) var expanded = false
    private var appearanceColor = NSColor.black
    private var appearanceOpacity: CGFloat = 1
    var onClick: (() -> Void)?
    var geometry: NotchGeometry { didSet { update(animated: false) } }

    init(frame frameRect: NSRect, geometry: NotchGeometry) {
        self.geometry = geometry
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        shapeLayer.fillColor = NSColor.black.cgColor
        shapeLayer.strokeColor = nil
        layer?.addSublayer(shapeLayer)

        glassMask.fillColor = NSColor.clear.cgColor
        glassMask.strokeColor = NSColor.white.cgColor
        glassMask.lineWidth = 1.15
        glassMask.lineCap = .round
        glassGradient.colors = [
            NSColor(calibratedRed: 0.30, green: 0.68, blue: 0.88, alpha: 0.09).cgColor,
            NSColor(calibratedWhite: 1, alpha: 0.30).cgColor,
            NSColor(calibratedRed: 0.38, green: 0.82, blue: 1, alpha: 0.12).cgColor,
            NSColor(calibratedWhite: 1, alpha: 0.20).cgColor
        ]
        glassGradient.locations = [0, 0.28, 0.66, 1]
        glassGradient.startPoint = CGPoint(x: 0, y: 0)
        glassGradient.endPoint = CGPoint(x: 1, y: 1)
        glassGradient.mask = glassMask
        layer?.addSublayer(glassGradient)
        startGlassAnimation()

        configureBeam(beamGlow, width: 3.0, alpha: 0.14, blur: 7)
        configureBeam(beamCore, width: 0.8, alpha: 0.52, blur: 1.5)
        layer?.addSublayer(beamGlow)
        layer?.addSublayer(beamCore)
        startBeamAnimation()
        update(animated: false)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var isFlipped: Bool { true }

    override func layout() {
        super.layout()
        shapeLayer.frame = bounds
        glassGradient.frame = bounds
        glassMask.frame = bounds
        for beam in [beamGlow, beamCore] { beam.frame = bounds }
        guard shapeLayer.animation(forKey: "morph") == nil else { return }
        update(animated: false)
    }

    func setExpanded(_ value: Bool, animated: Bool = true) {
        guard value != expanded else { return }
        expanded = value
        update(animated: animated)
    }

    func setAppearance(color: NSColor, opacity: CGFloat) {
        appearanceColor = color
        appearanceOpacity = min(max(opacity, 0.12), 1)
        shapeLayer.fillColor = color.withAlphaComponent(appearanceOpacity).cgColor
    }

    private func silhouette(expanded: Bool) -> CGPath {
        let centerX = bounds.midX
        let rect: CGRect
        let radius: CGFloat
        if expanded {
            rect = CGRect(x: 8, y: 0, width: bounds.width - 16, height: geometry.expandedHeight)
            radius = 17
        } else {
            rect = CGRect(
                x: centerX - geometry.hardwareWidth / 2,
                y: 0,
                width: geometry.hardwareWidth,
                height: geometry.hardwareHeight
            )
            radius = 0
        }
        return CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    }

    /// The glass and beam run only down the sides and across the bottom. The
    /// top control strip is intentionally excluded.
    private func outerEdge(expanded: Bool) -> CGPath {
        guard expanded else { return CGMutablePath() }
        let left: CGFloat = 8
        let right = bounds.width - 8
        let bottom = geometry.expandedHeight
        let radius: CGFloat = 17
        let startY = geometry.hardwareHeight
        let path = CGMutablePath()
        path.move(to: CGPoint(x: right, y: startY))
        path.addLine(to: CGPoint(x: right, y: bottom - radius))
        path.addQuadCurve(
            to: CGPoint(x: right - radius, y: bottom),
            control: CGPoint(x: right, y: bottom)
        )
        path.addLine(to: CGPoint(x: left + radius, y: bottom))
        path.addQuadCurve(
            to: CGPoint(x: left, y: bottom - radius),
            control: CGPoint(x: left, y: bottom)
        )
        path.addLine(to: CGPoint(x: left, y: startY))
        return path
    }

    private func configureBeam(_ beam: CAShapeLayer, width: CGFloat, alpha: CGFloat, blur: CGFloat) {
        beam.fillColor = NSColor.clear.cgColor
        beam.strokeColor = NSColor(calibratedRed: 0.58, green: 0.88, blue: 1, alpha: alpha).cgColor
        beam.lineWidth = width
        beam.lineCap = .round
        beam.lineJoin = .round
        beam.lineDashPattern = [58, 1700]
        beam.shadowColor = NSColor(calibratedRed: 0.34, green: 0.75, blue: 1, alpha: 0.55).cgColor
        beam.shadowRadius = blur
        beam.shadowOpacity = Float(alpha)
        beam.shadowOffset = .zero
        beam.opacity = 0
    }

    private func startBeamAnimation() {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        for (index, beam) in [beamGlow, beamCore].enumerated() {
            let travel = CABasicAnimation(keyPath: "lineDashPhase")
            travel.fromValue = CGFloat(index) * -2
            travel.toValue = -1758 + CGFloat(index) * -2
            travel.duration = 9
            travel.repeatCount = .infinity
            travel.timingFunction = CAMediaTimingFunction(name: .linear)
            beam.add(travel, forKey: "outerBorderBeam")
        }
    }

    private func startGlassAnimation() {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        let shimmer = CABasicAnimation(keyPath: "locations")
        shimmer.fromValue = [-0.34, -0.08, 0.18, 0.44]
        shimmer.toValue = [0.56, 0.82, 1.08, 1.34]
        shimmer.duration = 6.8
        shimmer.repeatCount = .infinity
        shimmer.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        glassGradient.add(shimmer, forKey: "glassShimmer")
    }

    private func update(animated: Bool) {
        shapeLayer.frame = bounds
        glassGradient.frame = bounds
        glassMask.frame = bounds
        for beam in [beamGlow, beamCore] { beam.frame = bounds }

        let newShape = silhouette(expanded: expanded)
        let newEdge = outerEdge(expanded: expanded)
        let duration = expanded ? 0.42 : 0.28
        let timing = CAMediaTimingFunction(controlPoints: 0.22, 0.88, 0.24, 1)

        if animated {
            animatePath(shapeLayer, to: newShape, duration: duration, timing: timing)
            let shellFade = CABasicAnimation(keyPath: "opacity")
            shellFade.fromValue = shapeLayer.presentation()?.opacity ?? shapeLayer.opacity
            shellFade.toValue = expanded ? 1 : 0
            shellFade.duration = expanded ? 0.18 : 0.12
            shapeLayer.add(shellFade, forKey: "shellFade")
            shapeLayer.opacity = expanded ? 1 : 0
            animatePath(glassMask, to: newEdge, duration: duration, timing: timing)
            for beam in [beamGlow, beamCore] {
                animatePath(beam, to: newEdge, duration: duration, timing: timing)
                let fade = CABasicAnimation(keyPath: "opacity")
                fade.fromValue = beam.presentation()?.opacity ?? beam.opacity
                fade.toValue = expanded ? 1 : 0
                fade.duration = expanded ? 0.35 : 0.14
                beam.add(fade, forKey: "beamFade")
                beam.opacity = expanded ? 1 : 0
            }
        } else {
            shapeLayer.path = newShape
            shapeLayer.opacity = expanded ? 1 : 0
            glassMask.path = newEdge
            for beam in [beamGlow, beamCore] {
                beam.path = newEdge
                beam.opacity = expanded ? 1 : 0
            }
        }
        glassGradient.opacity = expanded ? 1 : 0
    }

    private func animatePath(_ layer: CAShapeLayer, to path: CGPath, duration: CFTimeInterval, timing: CAMediaTimingFunction) {
        let animation = CABasicAnimation(keyPath: "path")
        animation.fromValue = layer.presentation()?.path ?? layer.path
        animation.toValue = path
        animation.duration = duration
        animation.timingFunction = timing
        layer.add(animation, forKey: "morph")
        layer.path = path
    }

    override func mouseDown(with event: NSEvent) { onClick?() }
}
