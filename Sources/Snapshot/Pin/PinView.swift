import Cocoa

final class PinView: NSView {
    let image: NSImage

    init(frame: NSRect, image: NSImage) {
        self.image = image
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        image.draw(in: bounds)
        NSColor.black.withAlphaComponent(0.35).setStroke()
        let border = NSBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5))
        border.lineWidth = 1
        border.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 { (window as? PinWindow)?.closePin() } else { super.mouseDown(with: event) }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { (window as? PinWindow)?.closePin() } else { super.keyDown(with: event) }
    }

    /// Scrolling resizes the pin around its centre, keeping the aspect ratio.
    override func scrollWheel(with event: NSEvent) {
        guard let w = window else { return }
        let aspect = image.size.width / image.size.height
        let factor = 1 + event.scrollingDeltaY * (event.hasPreciseScrollingDeltas ? 0.004 : 0.03)
        var width = w.frame.width * factor
        width = min(max(width, 60), 4000)
        let size = NSSize(width: width, height: width / aspect)
        let c = CGPoint(x: w.frame.midX, y: w.frame.midY)
        w.setFrame(NSRect(x: c.x - size.width / 2, y: c.y - size.height / 2, width: size.width, height: size.height), display: true)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let m = NSMenu()
        m.addItem(withTitle: "Copy", action: #selector(copyPin), keyEquivalent: "").target = self
        m.addItem(withTitle: "Save", action: #selector(savePin), keyEquivalent: "").target = self
        let op = NSMenuItem(title: "Opacity", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        for pct in [100, 75, 50, 25] {
            let i = sub.addItem(withTitle: "\(pct)%", action: #selector(setOpacity(_:)), keyEquivalent: "")
            i.tag = pct
            i.target = self
            i.state = abs((window?.alphaValue ?? 1) * 100 - Double(pct)) < 1 ? .on : .off
        }
        op.submenu = sub
        m.addItem(op)
        m.addItem(.separator())
        m.addItem(withTitle: "Close", action: #selector(closePin), keyEquivalent: "").target = self
        return m
    }

    private var png: Data? {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        return NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])
    }

    @objc func copyPin() {
        guard let png = png else { return }
        Pasteboard.copy(png: png)
    }

    @objc func savePin() { if let png = png { Output.save(png: png) } }
    @objc func setOpacity(_ sender: NSMenuItem) { window?.alphaValue = CGFloat(sender.tag) / 100 }
    @objc func closePin() { (window as? PinWindow)?.closePin() }
}
