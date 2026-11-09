import Cocoa

extension ToolSpec {
    /// A filled circle with the next step number in it.
    static let step = ToolSpec(tool: .step, symbol: "1.circle.fill", title: "Step number", interaction: .click) { a, _ in
        guard let center = a.points.first else { return }
        let radius: CGFloat = 13
        let circle = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        a.color.setFill()
        NSBezierPath(ovalIn: circle).fill()
        NSColor.white.withAlphaComponent(0.9).setStroke()
        let ring = NSBezierPath(ovalIn: circle.insetBy(dx: 1, dy: 1))
        ring.lineWidth = 1.5
        ring.stroke()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .bold),
            .foregroundColor: a.color.readableForegroundColor,
        ]
        let label = "\(a.number)" as NSString
        let size = label.size(withAttributes: attrs)
        label.draw(at: CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2), withAttributes: attrs)
    }
}

extension NSColor {
    /// Black or white, whichever reads better on top of this colour.
    var readableForegroundColor: NSColor {
        guard let c = usingColorSpace(.sRGB) else { return .white }
        let luminance = 0.2126 * c.redComponent + 0.7152 * c.greenComponent + 0.0722 * c.blueComponent
        return luminance > 0.6 ? .black : .white
    }
}
