import Cocoa

/// Click-through overlay shown while recording: dims everything outside the recorded area and outlines it.
final class RecordingFrameView: NSView {
    let area: CGRect
    init(frame: NSRect, area: CGRect) {
        self.area = area
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError() }
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let dim = NSBezierPath(rect: bounds)
        dim.append(NSBezierPath(rect: area))
        dim.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.35).setFill()
        dim.fill()
        // Border sits just outside the area so it never appears in the video.
        NSColor.systemRed.setStroke()
        let border = NSBezierPath(rect: area.insetBy(dx: -1.5, dy: -1.5))
        border.lineWidth = 3
        border.stroke()
    }
}

func makeRecordingFrame(screen: NSScreen, area: CGRect) -> NSWindow {
    let w = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
    w.level = .screenSaver
    w.isOpaque = false
    w.backgroundColor = .clear
    w.hasShadow = false
    w.ignoresMouseEvents = true
    w.isReleasedWhenClosed = false
    w.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
    w.contentView = RecordingFrameView(frame: CGRect(origin: .zero, size: screen.frame.size), area: area)
    w.setFrame(screen.frame, display: true)
    w.orderFrontRegardless()
    return w
}
