import AppKit
import SwiftUI

struct BusyBorderView: NSViewRepresentable {
    let claims: [BusyClaim]
    let cornerRadius: CGFloat

    func makeNSView(context: Context) -> BusyBorderLayerHost {
        let view = BusyBorderLayerHost()
        view.update(claims: claims, cornerRadius: cornerRadius)
        return view
    }

    func updateNSView(_ nsView: BusyBorderLayerHost, context: Context) {
        nsView.update(claims: claims, cornerRadius: cornerRadius)
    }
}

final class BusyBorderLayerHost: NSView {
    private let pulseLayer = CAShapeLayer()
    private var owners: [String] = []
    private var cornerRadius: CGFloat = 12
    private let outsideOffset: CGFloat = 2
    private let pulseLowOpacity: CGFloat = 0.25
    private let pulseHighOpacity: CGFloat = 0.85
    private let pulseDuration: Double = 1.2

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = false
        configureLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.masksToBounds = false
        configureLayer()
    }

    override func layout() {
        super.layout()
        updatePath()
    }

    func update(claims: [BusyClaim], cornerRadius: CGFloat) {
        self.cornerRadius = cornerRadius
        let nextOwners = claims.map(\.owner)
        if nextOwners != owners {
            owners = nextOwners
            updateAnimation()
        }
        updatePath()
    }

    private func configureLayer() {
        pulseLayer.fillColor = NSColor.clear.cgColor
        pulseLayer.strokeColor = NSColor.clear.cgColor
        pulseLayer.lineWidth = 1.6
        pulseLayer.lineJoin = .round
        pulseLayer.lineCap = .round
        pulseLayer.opacity = Float(pulseLowOpacity)
        layer?.addSublayer(pulseLayer)
    }

    private func updateAnimation() {
        pulseLayer.removeAnimation(forKey: "pulse")
        guard !owners.isEmpty else {
            pulseLayer.strokeColor = NSColor.clear.cgColor
            pulseLayer.opacity = 0
            return
        }

        let colors = owners.map { Theme.busyRingNSColor(for: $0).cgColor }
        let count = Double(colors.count)

        let colorAnimation = CAKeyframeAnimation(keyPath: "strokeColor")
        colorAnimation.values = colors
        colorAnimation.keyTimes = colors.indices.map { NSNumber(value: Double($0) / count) }
        colorAnimation.calculationMode = .discrete

        var opacityValues: [CGFloat] = [pulseLowOpacity]
        var opacityTimes: [NSNumber] = [0]
        for index in colors.indices {
            let mid = (Double(index) + 0.5) / count
            let end = Double(index + 1) / count
            opacityTimes.append(NSNumber(value: mid))
            opacityValues.append(pulseHighOpacity)
            opacityTimes.append(NSNumber(value: end))
            opacityValues.append(pulseLowOpacity)
        }

        let opacityAnimation = CAKeyframeAnimation(keyPath: "opacity")
        opacityAnimation.values = opacityValues
        opacityAnimation.keyTimes = opacityTimes
        opacityAnimation.calculationMode = .linear

        let group = CAAnimationGroup()
        group.animations = [colorAnimation, opacityAnimation]
        group.duration = pulseDuration * count
        group.repeatCount = .infinity
        group.timingFunction = CAMediaTimingFunction(name: .linear)
        group.isRemovedOnCompletion = false

        pulseLayer.strokeColor = colors[0]
        pulseLayer.opacity = Float(pulseLowOpacity)
        pulseLayer.add(group, forKey: "pulse")
    }

    private func updatePath() {
        guard !bounds.isEmpty else { return }
        let rect = bounds.insetBy(dx: -outsideOffset, dy: -outsideOffset)
        let radius = cornerRadius + outsideOffset
        pulseLayer.path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        pulseLayer.frame = bounds
    }
}
