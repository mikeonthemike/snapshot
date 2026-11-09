import Cocoa

/// Draws a dark pill with a hint near the top of a view. Call from a view's `draw`.
func drawHintBanner(_ text: String, in bounds: CGRect) {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 15, weight: .medium), .foregroundColor: NSColor.white,
    ]
    let size = (text as NSString).size(withAttributes: attrs)
    let pill = CGRect(x: bounds.midX - size.width / 2 - 16, y: 60, width: size.width + 32, height: size.height + 16)
    NSColor.black.withAlphaComponent(0.75).setFill()
    NSBezierPath(roundedRect: pill, xRadius: pill.height / 2, yRadius: pill.height / 2).fill()
    (text as NSString).draw(at: CGPoint(x: pill.minX + 16, y: pill.minY + 8), withAttributes: attrs)
}
