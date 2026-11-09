import Cocoa

/// Full-screen overlay showing a frozen screenshot. The user drags out a selection, annotates it, then
/// copies, saves, pins or records it. This file holds the state, drawing and mouse/keyboard handling;
/// the text editor, toolbar and output actions live in the `CaptureView+…` extensions.
final class CaptureView: NSView {
    weak var delegate: CaptureViewDelegate?

    let image: NSImage
    let scale: CGFloat
    var selection: CGRect?
    var tool = Tool.select
    var color = annotationPalette[0]
    var annotations: [Annotation] = []
    var current: Annotation?
    var dragStart: CGPoint?
    var toolbar: NSView?
    var toolButtons: [Tool: NSButton] = [:]
    var colorButton: NSButton?
    var textField: NSTextField?
    var textOrigin = CGPoint.zero
    var activeHandle: SelectionHandle?
    var moveOrigin: CGPoint?
    var originalSelection = CGRect.zero
    /// The unannotated screenshot as pixels, for tools (pixelate) that sample it.
    lazy var sourceImage: CGImage? = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    /// What Return does: copy the image, start recording, or copy the recognised text.
    var mode = CaptureMode.image

    init(frame: NSRect, image: NSImage, scale: CGFloat) {
        self.image = image
        self.scale = scale
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    // MARK: Cursor

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .activeAlways, .inVisibleRect], owner: self))
    }

    override func mouseMoved(with event: NSEvent) { refreshCursor(at: convert(event.locationInWindow, from: nil)) }

    func refreshCursor(at p: CGPoint? = nil) {
        let loc = p ?? window.map { convert($0.mouseLocationOutsideOfEventStream, from: nil) } ?? .zero
        cursor(at: loc).set()
    }

    func cursor(at p: CGPoint) -> NSCursor {
        guard let s = selection, dragStart == nil else { return .crosshair }
        if moveOrigin != nil { return .closedHand }
        if let h = activeHandle ?? handle(at: p) { return h.cursor }
        if toolbar?.frame.contains(p) == true { return .arrow }
        if tool == .select, s.contains(p) { return .openHand }
        return .arrow
    }

    // MARK: Selection

    func handle(at p: CGPoint) -> SelectionHandle? {
        guard let s = selection, toolbar?.frame.contains(p) != true else { return nil }
        return SelectionGeometry.handle(at: p, in: s)
    }

    func positionToolbar() {
        guard let s = selection, let fx = toolbar else { return }
        fx.frame.origin = SelectionGeometry.toolbarOrigin(size: fx.frame.size, selection: s, bounds: bounds)
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        image.draw(in: bounds, from: .zero, operation: .copy, fraction: 1, respectFlipped: true, hints: nil)
        let dim = NSBezierPath(rect: bounds)
        if let s = selection { dim.append(NSBezierPath(rect: s)) }
        dim.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.45).setFill()
        dim.fill()

        guard let s = selection else {
            if mode == .text { drawHintBanner("Drag over the text you want to copy  ·  Esc to cancel", in: bounds) }
            return
        }
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: s).addClip()
        let context = annotationContext
        annotations.forEach { $0.draw(in: context) }
        current?.draw(in: context)
        NSGraphicsContext.restoreGraphicsState()

        NSColor.systemBlue.setStroke()
        let border = NSBezierPath(rect: s)
        border.lineWidth = 1
        border.stroke()

        NSColor.white.setFill()
        for h in SelectionHandle.allCases {
            let r = SelectionGeometry.handleRect(h, in: s)
            let dot = NSBezierPath(ovalIn: r.insetBy(dx: 1, dy: 1))
            dot.fill()
            NSColor.systemBlue.setStroke()
            dot.lineWidth = 1
            dot.stroke()
        }

        let label = "\(Int(s.width)) × \(Int(s.height))" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium), .foregroundColor: NSColor.white,
        ]
        let size = label.size(withAttributes: attrs)
        let pill = CGRect(x: s.minX, y: max(s.minY - size.height - 10, 4), width: size.width + 12, height: size.height + 4)
        NSColor.black.withAlphaComponent(0.7).setFill()
        NSBezierPath(roundedRect: pill, xRadius: 4, yRadius: 4).fill()
        label.draw(at: CGPoint(x: pill.minX + 6, y: pill.minY + 2), withAttributes: attrs)
    }

    // MARK: Mouse

    override func mouseDown(with event: NSEvent) {
        commitText()
        let p = convert(event.locationInWindow, from: nil)
        if let s = selection, let h = handle(at: p) {
            activeHandle = h
            originalSelection = s
            toolbar?.isHidden = true
        } else if let s = selection, s.contains(p), tool == .select {
            moveOrigin = p
            originalSelection = s
            toolbar?.isHidden = true
        } else if let s = selection, tool != .select, s.contains(p) {
            beginAnnotation(at: p)
        } else {
            toolbar?.removeFromSuperview()
            toolbar = nil
            toolButtons = [:]
            selection = nil
            annotations = []
            tool = .select
            dragStart = p
        }
        refreshCursor(at: p)
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        var p = convert(event.locationInWindow, from: nil)
        if let start = dragStart {
            selection = CGRect.spanning(start, p).intersection(bounds)
        } else if let h = activeHandle {
            selection = SelectionGeometry.resized(originalSelection, dragging: h, to: p, within: bounds)
        } else if let origin = moveOrigin {
            let prev = selection!
            let delta = CGPoint(x: p.x - origin.x, y: p.y - origin.y)
            selection = SelectionGeometry.moved(originalSelection, by: delta, within: bounds)
            let ddx = selection!.minX - prev.minX, ddy = selection!.minY - prev.minY
            for i in annotations.indices {
                annotations[i].points = annotations[i].points.map { CGPoint(x: $0.x + ddx, y: $0.y + ddy) }
            }
        } else if current != nil, let s = selection {
            p.x = min(max(p.x, s.minX), s.maxX)
            p.y = min(max(p.y, s.minY), s.maxY)
            if AnnotationTools.spec(for: current!.tool)?.interaction == .freehand {
                current!.points.append(p)
            } else {
                current!.points = [current!.points[0], p]
            }
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if dragStart != nil {
            dragStart = nil
            if let s = selection, s.width > 4, s.height > 4 {
                if mode == .text {
                    copyText()
                    return
                }
                showToolbar()
            } else {
                selection = nil
            }
        } else if activeHandle != nil || moveOrigin != nil {
            activeHandle = nil
            moveOrigin = nil
            if let s = selection, s.width < 8 || s.height < 8 { selection = originalSelection }
            toolbar?.isHidden = false
            positionToolbar()
        } else if let c = current {
            if c.points.count > 1 { annotations.append(c) }
            current = nil
        }
        refreshCursor(at: convert(event.locationInWindow, from: nil))
        needsDisplay = true
    }

    // MARK: Keyboard

    override func keyDown(with event: NSEvent) {
        let cmd = event.modifierFlags.contains(.command)
        switch (event.keyCode, event.charactersIgnoringModifiers) {
        case (53, _): cancel()
        case (36, _), (76, _): if selection != nil { returnPressed() }
        case (_, "c") where cmd: if selection != nil { copyImage() }
        case (_, "p") where cmd: if selection != nil { pin() }
        case (_, "r") where cmd: if selection != nil { record() }
        case (_, "t") where cmd: if selection != nil { copyText() }
        case (_, "s") where cmd: if selection != nil { save() }
        case (_, "z") where cmd: undo()
        default: super.keyDown(with: event)
        }
    }
}
