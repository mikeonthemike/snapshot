import Cocoa

protocol WindowPickerDelegate: AnyObject {
    func windowPickerDidCancel(_ view: WindowPickerView)
    func windowPicker(_ view: WindowPickerView, didPick window: WindowInfo)
}

/// Full-screen overlay over a frozen screenshot that highlights the window under the cursor.
/// Click to pick it, Esc to cancel.
final class WindowPickerView: NSView {
    weak var delegate: WindowPickerDelegate?

    private let image: NSImage
    private let windows: [WindowInfo]
    /// This display's frame in global (Quartz) coordinates.
    private let displayBounds: CGRect
    private(set) var hovered: WindowInfo?

    init(frame: NSRect, image: NSImage, windows: [WindowInfo], displayBounds: CGRect) {
        self.image = image
        self.windows = windows
        self.displayBounds = displayBounds
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .activeAlways, .inVisibleRect], owner: self))
    }

    override func mouseMoved(with event: NSEvent) { updateHover(at: convert(event.locationInWindow, from: nil)) }

    /// Highlights whatever is under the cursor right now (call once after the overlay appears).
    func updateHover() {
        guard let w = window else { return }
        updateHover(at: convert(w.mouseLocationOutsideOfEventStream, from: nil))
    }

    private func updateHover(at local: CGPoint) {
        let global = CGPoint(x: local.x + displayBounds.minX, y: local.y + displayBounds.minY)
        let found = WindowList.topmost(at: global, in: windows)
        if found != hovered {
            hovered = found
            needsDisplay = true
        }
    }

    private var highlightRect: CGRect? {
        hovered.map { $0.localBounds(onDisplay: displayBounds).intersection(bounds) }
    }

    override func draw(_ dirtyRect: NSRect) {
        image.draw(in: bounds, from: .zero, operation: .copy, fraction: 1, respectFlipped: true, hints: nil)
        let dim = NSBezierPath(rect: bounds)
        if let r = highlightRect { dim.append(NSBezierPath(rect: r)) }
        dim.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.45).setFill()
        dim.fill()

        drawHintBanner("Click a window to capture it  ·  Esc to cancel", in: bounds)

        guard let r = highlightRect, let h = hovered else { return }
        NSColor.systemBlue.setStroke()
        let border = NSBezierPath(rect: r.insetBy(dx: 1, dy: 1))
        border.lineWidth = 3
        border.stroke()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium), .foregroundColor: NSColor.white,
        ]
        let label = h.label as NSString
        let size = label.size(withAttributes: attrs)
        let pill = CGRect(x: r.minX + 8, y: r.minY + 8, width: min(size.width + 16, max(r.width - 16, 0)), height: size.height + 6)
        NSColor.systemBlue.setFill()
        NSBezierPath(roundedRect: pill, xRadius: 5, yRadius: 5).fill()
        label.draw(in: pill.insetBy(dx: 8, dy: 3), withAttributes: attrs)
    }

    override func mouseDown(with event: NSEvent) {
        updateHover(at: convert(event.locationInWindow, from: nil))
        if let h = hovered { delegate?.windowPicker(self, didPick: h) }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { delegate?.windowPickerDidCancel(self) } else { super.keyDown(with: event) }
    }
}
