import Cocoa
import Carbon.HIToolbox
import ScreenCaptureKit
import AVFoundation

// MARK: - Annotations

enum Tool { case select, rect, arrow, pen, text }

struct Annotation {
    var tool: Tool
    var points: [CGPoint]
    var color: NSColor
    var text = ""
}

enum Handle: CaseIterable {
    case topLeft, top, topRight, left, right, bottomLeft, bottom, bottomRight

    /// Position along each axis (0 = min edge, 0.5 = middle, 1 = max edge) in the view's flipped coordinates.
    var factors: (CGFloat, CGFloat) {
        switch self {
        case .topLeft: return (0, 0)
        case .top: return (0.5, 0)
        case .topRight: return (1, 0)
        case .left: return (0, 0.5)
        case .right: return (1, 0.5)
        case .bottomLeft: return (0, 1)
        case .bottom: return (0.5, 1)
        case .bottomRight: return (1, 1)
        }
    }

    var cursor: NSCursor {
        if #available(macOS 15.0, *) {
            let pos: NSCursor.FrameResizePosition
            switch self {
            case .topLeft: pos = .topLeft
            case .top: pos = .top
            case .topRight: pos = .topRight
            case .left: pos = .left
            case .right: pos = .right
            case .bottomLeft: pos = .bottomLeft
            case .bottom: pos = .bottom
            case .bottomRight: pos = .bottomRight
            }
            return NSCursor.frameResize(position: pos, directions: .all)
        }
        switch self {
        case .top, .bottom: return .resizeUpDown
        default: return .resizeLeftRight
        }
    }
}

let palette: [NSColor] = [.systemRed, .systemOrange, .systemYellow, .systemGreen, .systemBlue, .white, .black]

func rectFrom(_ a: CGPoint, _ b: CGPoint) -> CGRect {
    CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
}

func drawAnnotation(_ a: Annotation) {
    a.color.setStroke()
    a.color.setFill()
    guard let first = a.points.first, let last = a.points.last else { return }
    switch a.tool {
    case .rect:
        let p = NSBezierPath(rect: rectFrom(first, last))
        p.lineWidth = 3
        p.stroke()
    case .arrow:
        let line = NSBezierPath()
        line.lineWidth = 3
        line.lineCapStyle = .round
        line.move(to: first)
        line.line(to: last)
        line.stroke()
        let angle = atan2(last.y - first.y, last.x - first.x)
        let len: CGFloat = 16
        let head = NSBezierPath()
        head.move(to: last)
        head.line(to: CGPoint(x: last.x - len * cos(angle - .pi / 7), y: last.y - len * sin(angle - .pi / 7)))
        head.line(to: CGPoint(x: last.x - len * cos(angle + .pi / 7), y: last.y - len * sin(angle + .pi / 7)))
        head.close()
        head.fill()
    case .pen:
        let p = NSBezierPath()
        p.lineWidth = 3
        p.lineCapStyle = .round
        p.lineJoinStyle = .round
        p.move(to: first)
        a.points.dropFirst().forEach { p.line(to: $0) }
        p.stroke()
    case .text:
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 20), .foregroundColor: a.color,
        ]
        NSAttributedString(string: a.text, attributes: attrs).draw(at: first)
    case .select:
        break
    }
}

// MARK: - Capture view

final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class CaptureView: NSView, NSTextFieldDelegate {
    let image: NSImage
    let scale: CGFloat
    var selection: CGRect?
    var tool = Tool.select
    var color = palette[0]
    var annotations: [Annotation] = []
    var current: Annotation?
    var dragStart: CGPoint?
    var toolbar: NSView?
    var toolButtons: [Tool: NSButton] = [:]
    var colorButton: NSButton?
    var textField: NSTextField?
    var textOrigin = CGPoint.zero
    var activeHandle: Handle?
    var moveOrigin: CGPoint?
    var originalSelection = CGRect.zero

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

    // MARK: Handles

    func handleRect(_ h: Handle, in s: CGRect) -> CGRect {
        let (fx, fy) = h.factors
        return CGRect(x: s.minX + s.width * fx - 5, y: s.minY + s.height * fy - 5, width: 10, height: 10)
    }

    func handle(at p: CGPoint) -> Handle? {
        guard let s = selection, toolbar?.frame.contains(p) != true else { return nil }
        return Handle.allCases.first { handleRect($0, in: s).insetBy(dx: -3, dy: -3).contains(p) }
    }

    func positionToolbar() {
        guard let s = selection, let fx = toolbar else { return }
        let size = fx.frame.size
        var origin = CGPoint(x: s.maxX - size.width, y: s.maxY + 8)
        if origin.y + size.height > bounds.maxY - 4 { origin.y = s.minY - size.height - 30 }
        if origin.y < 4 { origin.y = s.maxY - size.height - 8 }
        origin.x = min(max(origin.x, 8), bounds.maxX - size.width - 8)
        fx.frame.origin = origin
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        image.draw(in: bounds, from: .zero, operation: .copy, fraction: 1, respectFlipped: true, hints: nil)
        let dim = NSBezierPath(rect: bounds)
        if let s = selection { dim.append(NSBezierPath(rect: s)) }
        dim.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.45).setFill()
        dim.fill()

        guard let s = selection else { return }
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: s).addClip()
        annotations.forEach(drawAnnotation)
        if let c = current { drawAnnotation(c) }
        NSGraphicsContext.restoreGraphicsState()

        NSColor.systemBlue.setStroke()
        let border = NSBezierPath(rect: s)
        border.lineWidth = 1
        border.stroke()

        NSColor.white.setFill()
        for h in Handle.allCases {
            let r = handleRect(h, in: s)
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
            if tool == .text {
                beginText(at: p)
            } else {
                current = Annotation(tool: tool, points: [p], color: color)
            }
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
            selection = rectFrom(start, p).intersection(bounds)
        } else if let h = activeHandle {
            let o = originalSelection
            let (fx, fy) = h.factors
            var x0 = o.minX, x1 = o.maxX, y0 = o.minY, y1 = o.maxY
            if fx == 0 { x0 = p.x } else if fx == 1 { x1 = p.x }
            if fy == 0 { y0 = p.y } else if fy == 1 { y1 = p.y }
            selection = rectFrom(CGPoint(x: x0, y: y0), CGPoint(x: x1, y: y1)).intersection(bounds)
        } else if let origin = moveOrigin {
            var dx = p.x - origin.x, dy = p.y - origin.y
            let o = originalSelection
            dx = min(max(dx, -o.minX), bounds.maxX - o.maxX)
            dy = min(max(dy, -o.minY), bounds.maxY - o.maxY)
            let prev = selection!
            selection = o.offsetBy(dx: dx, dy: dy)
            let ddx = selection!.minX - prev.minX, ddy = selection!.minY - prev.minY
            for i in annotations.indices {
                annotations[i].points = annotations[i].points.map { CGPoint(x: $0.x + ddx, y: $0.y + ddy) }
            }
        } else if current != nil, let s = selection {
            p.x = min(max(p.x, s.minX), s.maxX)
            p.y = min(max(p.y, s.minY), s.maxY)
            if current!.tool == .pen { current!.points.append(p) } else { current!.points = [current!.points[0], p] }
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if dragStart != nil {
            dragStart = nil
            if let s = selection, s.width > 4, s.height > 4 {
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

    // MARK: Text

    func beginText(at p: CGPoint) {
        let field = NSTextField(frame: CGRect(x: p.x, y: p.y, width: 220, height: 26))
        field.font = .boldSystemFont(ofSize: 20)
        field.textColor = color
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.delegate = self
        textOrigin = p
        textField = field
        addSubview(field)
        window?.makeFirstResponder(field)
    }

    func controlTextDidEndEditing(_ obj: Notification) { commitText() }

    func commitText() {
        guard let field = textField else { return }
        textField = nil
        let text = field.stringValue
        let col = field.textColor ?? color
        field.removeFromSuperview()
        if !text.isEmpty {
            annotations.append(Annotation(tool: .text, points: [CGPoint(x: textOrigin.x + 2, y: textOrigin.y + 2)], color: col, text: text))
        }
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    // MARK: Toolbar

    func button(_ symbol: String, _ tip: String, _ action: Selector) -> NSButton {
        let b = NSButton(image: NSImage(systemSymbolName: symbol, accessibilityDescription: tip)!, target: self, action: action)
        b.isBordered = false
        b.toolTip = tip
        b.wantsLayer = true
        b.layer?.cornerRadius = 6
        b.widthAnchor.constraint(equalToConstant: 30).isActive = true
        b.heightAnchor.constraint(equalToConstant: 28).isActive = true
        return b
    }

    func showToolbar() {
        guard selection != nil else { return }
        let items: [(Tool, String, String)] = [
            (.rect, "rectangle", "Rectangle"), (.arrow, "arrow.up.right", "Arrow"),
            (.pen, "pencil.tip", "Pen"), (.text, "textformat", "Text"),
        ]
        var views: [NSView] = []
        for (t, sym, tip) in items {
            let b = button(sym, tip, #selector(toolTapped(_:)))
            b.tag = items.firstIndex { $0.0 == t }!
            toolButtons[t] = b
            views.append(b)
        }
        let cb = button("circle.fill", "Color", #selector(cycleColor))
        cb.contentTintColor = color
        colorButton = cb
        views.append(cb)
        views.append(button("arrow.uturn.backward", "Undo (⌘Z)", #selector(undo)))
        views.append(button("xmark", "Cancel (Esc)", #selector(cancel)))
        views.append(button("pin", "Pin to screen (⌘P)", #selector(pin)))
        let rec = button("record.circle", "Record this area (⌘R)", #selector(record))
        rec.contentTintColor = .systemRed
        views.append(rec)
        views.append(button("square.and.arrow.down", "Save (⌘S)", #selector(save)))
        views.append(button("doc.on.doc", "Copy (⌘C / Return)", #selector(copyImage)))

        let stack = NSStackView(views: views)
        stack.spacing = 2
        stack.edgeInsets = NSEdgeInsets(top: 4, left: 6, bottom: 4, right: 6)
        let fx = NSVisualEffectView()
        fx.material = .hudWindow
        fx.state = .active
        fx.wantsLayer = true
        fx.layer?.cornerRadius = 10
        fx.layer?.masksToBounds = true
        stack.translatesAutoresizingMaskIntoConstraints = false
        fx.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: fx.leadingAnchor), stack.trailingAnchor.constraint(equalTo: fx.trailingAnchor),
            stack.topAnchor.constraint(equalTo: fx.topAnchor), stack.bottomAnchor.constraint(equalTo: fx.bottomAnchor),
        ])
        let size = stack.fittingSize
        fx.frame = CGRect(origin: .zero, size: size)
        addSubview(fx)
        toolbar = fx
        positionToolbar()
    }

    func updateToolHighlight() {
        for (t, b) in toolButtons {
            b.layer?.backgroundColor = (t == tool ? NSColor.white.withAlphaComponent(0.25) : .clear).cgColor
        }
    }

    @objc func toolTapped(_ sender: NSButton) {
        commitText()
        let order: [Tool] = [.rect, .arrow, .pen, .text]
        let t = order[sender.tag]
        tool = (tool == t) ? .select : t
        updateToolHighlight()
    }

    @objc func cycleColor() {
        let i = palette.firstIndex(of: color) ?? 0
        color = palette[(i + 1) % palette.count]
        colorButton?.contentTintColor = color
    }

    @objc func undo() {
        commitText()
        _ = annotations.popLast()
        needsDisplay = true
    }

    @objc func cancel() { CaptureController.shared.finish() }

    // MARK: Output

    func render() -> NSBitmapImageRep? {
        guard let sel = selection else { return nil }
        commitText()
        let w = Int(sel.width * scale), h = Int(sel.height * scale)
        guard let ctx = CGContext(
            data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: scale, y: -scale)
        ctx.translateBy(x: -sel.minX, y: -sel.minY)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
        image.draw(in: bounds, from: .zero, operation: .copy, fraction: 1, respectFlipped: true, hints: nil)
        annotations.forEach(drawAnnotation)
        NSGraphicsContext.restoreGraphicsState()
        return ctx.makeImage().map { NSBitmapImageRep(cgImage: $0) }
    }

    @objc func copyImage() {
        guard let rep = render(), let png = rep.representation(using: .png, properties: [:]) else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setData(png, forType: .png)
        CaptureController.shared.finish()
    }

    @objc func pin() {
        guard let sel = selection, let win = window, let screen = win.screen, let rep = render() else { return }
        let img = NSImage(size: sel.size)
        img.addRepresentation(rep)
        // View coordinates are flipped and screen-relative; convert to global AppKit coordinates.
        let frame = NSRect(x: screen.frame.minX + sel.minX, y: screen.frame.maxY - sel.maxY, width: sel.width, height: sel.height)
        CaptureController.shared.finish()
        PinWindow.pin(img, at: frame)
    }

    @objc func record() {
        guard let sel = selection, let win = window, let screen = win.screen else { return }
        commitText()
        let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? CGMainDisplayID()
        let rect = CGRect(x: sel.minX.rounded(), y: sel.minY.rounded(), width: sel.width.rounded(), height: sel.height.rounded())
        let scale = self.scale
        CaptureController.shared.finish()
        // Give the overlay a moment to disappear before the first frame is captured.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            Recorder.shared.start(displayID: id, rect: rect, scale: scale)
        }
    }

    @objc func save() {
        guard let rep = render(), let png = rep.representation(using: .png, properties: [:]) else { return }
        Output.save(png: png)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setData(png, forType: .png)
        CaptureController.shared.finish()
    }

    override func keyDown(with event: NSEvent) {
        let cmd = event.modifierFlags.contains(.command)
        switch (event.keyCode, event.charactersIgnoringModifiers) {
        case (53, _): cancel()
        case (36, _), (76, _): if selection != nil { copyImage() }
        case (_, "c") where cmd: if selection != nil { copyImage() }
        case (_, "p") where cmd: if selection != nil { pin() }
        case (_, "r") where cmd: if selection != nil { record() }
        case (_, "s") where cmd: if selection != nil { save() }
        case (_, "z") where cmd: undo()
        default: super.keyDown(with: event)
        }
    }
}

// MARK: - Output helpers

enum Output {
    static let defaultsKey = "saveFolderPath"

    static var defaultFolder: URL {
        FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
    }

    /// The user's chosen save folder, falling back to the Desktop if it is unset or has gone missing.
    static var folder: URL {
        get {
            if let path = UserDefaults.standard.string(forKey: defaultsKey) {
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                    return URL(fileURLWithPath: path, isDirectory: true)
                }
            }
            return defaultFolder
        }
        set {
            if newValue.standardizedFileURL == defaultFolder.standardizedFileURL {
                UserDefaults.standard.removeObject(forKey: defaultsKey)
            } else {
                UserDefaults.standard.set(newValue.path, forKey: defaultsKey)
            }
        }
    }

    static func newURL(prefix: String, ext: String) -> URL {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return folder.appendingPathComponent("\(prefix) \(f.string(from: Date())).\(ext)")
    }

    @discardableResult
    static func save(png: Data) -> URL? {
        let url = newURL(prefix: "Snapshot", ext: "png")
        do { try png.write(to: url); return url } catch { NSSound.beep(); return nil }
    }
}

// MARK: - Pinned screenshots

final class PinWindow: NSPanel {
    static var pins: [PinWindow] = []

    override var canBecomeKey: Bool { true }

    static func pin(_ image: NSImage, at frame: NSRect) {
        let w = PinWindow(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        w.level = .floating
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = true
        w.hidesOnDeactivate = false
        w.isReleasedWhenClosed = false
        w.isMovableByWindowBackground = true
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        w.contentView = PinView(frame: NSRect(origin: .zero, size: frame.size), image: image)
        pins.append(w)
        w.orderFrontRegardless()
    }

    func closePin() {
        orderOut(nil)
        PinWindow.pins.removeAll { $0 === self }
    }
}

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
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setData(png, forType: .png)
    }

    @objc func savePin() { if let png = png { Output.save(png: png) } }
    @objc func setOpacity(_ sender: NSMenuItem) { window?.alphaValue = CGFloat(sender.tag) / 100 }
    @objc func closePin() { (window as? PinWindow)?.closePin() }
}

// MARK: - Settings

final class SettingsController: NSObject {
    static let shared = SettingsController()
    private var window: NSWindow?
    private let pathField = NSTextField(labelWithString: "")

    func show() {
        if window == nil { build() }
        refresh()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func build() {
        let title = NSTextField(labelWithString: "Save screenshots and recordings to:")
        title.font = .boldSystemFont(ofSize: 13)
        pathField.lineBreakMode = .byTruncatingMiddle
        pathField.font = .systemFont(ofSize: 12)
        pathField.textColor = .secondaryLabelColor
        pathField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let choose = NSButton(title: "Choose…", target: self, action: #selector(choose))
        let reset = NSButton(title: "Reset to Desktop", target: self, action: #selector(reset))
        let buttons = NSStackView(views: [choose, reset])
        buttons.spacing = 8

        let stack = NSStackView(views: [title, pathField, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 130),
                         styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = "Snapshot Settings"
        w.isReleasedWhenClosed = false
        w.contentView = stack
        pathField.preferredMaxLayoutWidth = 400
        w.setContentSize(NSSize(width: 440, height: stack.fittingSize.height))
        w.center()
        window = w
    }

    private func refresh() {
        pathField.stringValue = (Output.folder.path as NSString).abbreviatingWithTildeInPath
    }

    @objc private func choose() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.directoryURL = Output.folder
        if let w = window {
            panel.beginSheetModal(for: w) { [weak self] r in
                if r == .OK, let url = panel.url { Output.folder = url; self?.refresh() }
            }
        }
    }

    @objc private func reset() {
        Output.folder = Output.defaultFolder
        refresh()
    }
}

// MARK: - Recording frame

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

// MARK: - Recording controller bar

/// Floating bar shown beside the recorded area: timer, pause/resume, mic, discard and stop.
final class RecordingController: NSObject {
    private let panel: NSPanel
    private let timeLabel = NSTextField(labelWithString: "0:00")
    private let dot = NSTextField(labelWithString: "●")
    private let pauseButton = NSButton()
    private let micButton = NSButton()
    private var timer: Timer?

    init(screen: NSScreen, area: CGRect) {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        super.init()
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        dot.textColor = .systemRed
        dot.font = .systemFont(ofSize: 12)
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        timeLabel.textColor = .white

        configure(pauseButton, "pause.fill", "Pause", #selector(togglePause))
        configure(micButton, "mic.fill", "Mute microphone", #selector(toggleMic))
        let discard = NSButton()
        configure(discard, "trash", "Discard recording", #selector(discardTapped))
        let stop = NSButton()
        configure(stop, "stop.circle.fill", "Stop and save", #selector(stopTapped))
        stop.contentTintColor = .systemRed

        let stack = NSStackView(views: [dot, timeLabel, pauseButton, micButton, discard, stop])
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 6, left: 12, bottom: 6, right: 8)
        stack.setCustomSpacing(10, after: timeLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let fx = NSVisualEffectView()
        fx.material = .hudWindow
        fx.state = .active
        fx.appearance = NSAppearance(named: .vibrantDark)
        fx.wantsLayer = true
        fx.layer?.cornerRadius = 12
        fx.layer?.masksToBounds = true
        fx.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: fx.leadingAnchor), stack.trailingAnchor.constraint(equalTo: fx.trailingAnchor),
            stack.topAnchor.constraint(equalTo: fx.topAnchor), stack.bottomAnchor.constraint(equalTo: fx.bottomAnchor),
        ])
        let size = stack.fittingSize
        fx.frame = CGRect(origin: .zero, size: size)
        panel.contentView = fx
        panel.setContentSize(size)
        place(size: size, screen: screen, area: area)
        panel.orderFrontRegardless()
    }

    private func configure(_ b: NSButton, _ symbol: String, _ tip: String, _ action: Selector) {
        b.image = NSImage(systemSymbolName: symbol, accessibilityDescription: tip)
        b.isBordered = false
        b.contentTintColor = .white
        b.toolTip = tip
        b.target = self
        b.action = action
        b.widthAnchor.constraint(equalToConstant: 28).isActive = true
        b.heightAnchor.constraint(equalToConstant: 26).isActive = true
    }

    private func place(size: NSSize, screen: NSScreen, area: CGRect) {
        let f = screen.frame
        let areaMinY = f.maxY - area.maxY   // bottom edge of the area, in AppKit coordinates
        let areaMaxY = f.maxY - area.minY   // top edge
        var y = areaMinY - size.height - 12
        if y < f.minY + 4 { y = areaMaxY + 12 }
        if y + size.height > f.maxY - 4 { y = areaMinY + 12 }
        var x = f.minX + area.midX - size.width / 2
        x = min(max(x, f.minX + 8), f.maxX - size.width - 8)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    var windowNumber: Int { panel.windowNumber }

    func begin() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.refresh() }
    }

    func close() {
        timer?.invalidate()
        panel.orderOut(nil)
    }

    private func refresh() {
        let r = Recorder.shared
        let t = Int(r.elapsed)
        timeLabel.stringValue = String(format: "%d:%02d", t / 60, t % 60)
        dot.textColor = r.isPaused ? .systemGray : .systemRed
        let pauseSymbol = r.isPaused ? "play.fill" : "pause.fill"
        pauseButton.image = NSImage(systemSymbolName: pauseSymbol, accessibilityDescription: nil)
        pauseButton.toolTip = r.isPaused ? "Resume" : "Pause"
        micButton.isEnabled = r.micAvailable
        let micOn = r.micAvailable && !r.micMuted
        micButton.image = NSImage(systemSymbolName: micOn ? "mic.fill" : "mic.slash.fill", accessibilityDescription: nil)
        micButton.contentTintColor = micOn ? .white : .systemOrange
        micButton.toolTip = !r.micAvailable ? "Microphone unavailable (check System Settings → Privacy → Microphone)"
            : (r.micMuted ? "Unmute microphone" : "Mute microphone")
    }

    @objc private func togglePause() { Recorder.shared.togglePause(); refresh() }
    @objc private func toggleMic() { Recorder.shared.toggleMic(); refresh() }
    @objc private func discardTapped() { Recorder.shared.stop(discard: true) }
    @objc private func stopTapped() { Recorder.shared.stop() }
}

// MARK: - Recorder

final class Recorder: NSObject, SCStreamOutput, SCStreamDelegate {
    static let shared = Recorder()

    // Main-thread state
    private(set) var isRecording = false
    private(set) var isPaused = false
    private(set) var micAvailable = false
    private(set) var micMuted = false
    var onChange: (() -> Void)?

    private var stream: SCStream?
    private var stopping = false
    private var url: URL?
    private var frameWindow: NSWindow?
    private var controller: RecordingController?
    private var startDate = Date()
    private var pausedTotal: TimeInterval = 0
    private var pauseBegan: Date?

    var elapsed: TimeInterval {
        let current = pauseBegan.map { Date().timeIntervalSince($0) } ?? 0
        return max(Date().timeIntervalSince(startDate) - pausedTotal - current, 0)
    }

    // Sample-queue state: only touched on `queue`
    private let queue = DispatchQueue(label: "snapshot.recorder")
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var started = false
    private var sessionStart = CMTime.zero
    private var audioFormat: CMFormatDescription?
    private var wantsMic = false
    private var qPaused = false
    private var qMuted = false
    private var offset = CMTime.zero
    private var pauseHostTime = CMTime.zero
    private var streamStart = Date()
    private var outputURL: URL?
    private var width = 0
    private var height = 0

    static func requestMic() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .audio)
        default: return false
        }
    }

    func start(displayID: CGDirectDisplayID, rect: CGRect, scale: CGFloat) {
        guard !isRecording else { return }
        isRecording = true
        stopping = false
        Task { @MainActor in
            do {
                var mic = false
                if #available(macOS 15.0, *) { mic = await Recorder.requestMic() }
                micAvailable = mic
                micMuted = false
                isPaused = false

                let screen = NSScreen.screens.first {
                    ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == displayID
                } ?? NSScreen.main
                if let screen = screen {
                    frameWindow = makeRecordingFrame(screen: screen, area: rect)
                    controller = RecordingController(screen: screen, area: rect)
                    try? await Task.sleep(nanoseconds: 150_000_000)
                }
                let content = try await SCShareableContent.current
                guard let display = content.displays.first(where: { $0.displayID == displayID }) ?? content.displays.first else {
                    throw NSError(domain: "Snapshot", code: 1, userInfo: [NSLocalizedDescriptionKey: "No display found."])
                }
                let hidden = [frameWindow?.windowNumber, controller?.windowNumber].compactMap { $0 }.map { CGWindowID($0) }
                let excluded = content.windows.filter { hidden.contains($0.windowID) }

                let w = max(Int(rect.width * scale) & ~1, 2), h = max(Int(rect.height * scale) & ~1, 2)
                let cfg = SCStreamConfiguration()
                cfg.sourceRect = rect
                cfg.width = w
                cfg.height = h
                cfg.minimumFrameInterval = CMTime(value: 1, timescale: 30)
                cfg.pixelFormat = kCVPixelFormatType_32BGRA
                cfg.showsCursor = true
                cfg.queueDepth = 6
                if #available(macOS 15.0, *), mic { cfg.captureMicrophone = true }

                let url = Output.newURL(prefix: "Recording", ext: "mov")
                self.url = url
                queue.sync {
                    writer = nil
                    videoInput = nil
                    audioInput = nil
                    started = false
                    audioFormat = nil
                    wantsMic = mic
                    qPaused = false
                    qMuted = false
                    offset = .zero
                    streamStart = Date()
                    outputURL = url
                    width = w
                    height = h
                }

                let stream = SCStream(filter: SCContentFilter(display: display, excludingWindows: excluded), configuration: cfg, delegate: self)
                try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
                if #available(macOS 15.0, *), mic {
                    try stream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: queue)
                }
                self.stream = stream
                try await stream.startCapture()
                startDate = Date()
                pausedTotal = 0
                pauseBegan = nil
                controller?.begin()
                onChange?()
            } catch {
                fail(error)
            }
        }
    }

    func togglePause() {
        guard isRecording, stream != nil else { return }
        if isPaused {
            pausedTotal += pauseBegan.map { Date().timeIntervalSince($0) } ?? 0
            pauseBegan = nil
            isPaused = false
            queue.sync {
                let gap = CMTimeSubtract(CMClockGetTime(CMClockGetHostTimeClock()), pauseHostTime)
                offset = CMTimeAdd(offset, gap)
                qPaused = false
            }
        } else {
            isPaused = true
            pauseBegan = Date()
            queue.sync {
                pauseHostTime = CMClockGetTime(CMClockGetHostTimeClock())
                qPaused = true
            }
        }
    }

    func toggleMic() {
        guard micAvailable else { return }
        micMuted.toggle()
        queue.sync { qMuted = micMuted }
    }

    func stop(discard: Bool = false) {
        guard isRecording, !stopping, let stream = stream else { return }
        stopping = true
        Task { @MainActor in
            try? await stream.stopCapture()
            let (writer, wasStarted): (AVAssetWriter?, Bool) = queue.sync {
                videoInput?.markAsFinished()
                audioInput?.markAsFinished()
                return (self.writer, started)
            }
            if wasStarted, let writer = writer {
                await writer.finishWriting()
            } else {
                writer?.cancelWriting()
            }
            let url = self.url
            reset()
            onChange?()
            guard let url = url else { return }
            let exists = FileManager.default.fileExists(atPath: url.path)
            if discard {
                try? FileManager.default.removeItem(at: url)
            } else if exists && wasStarted {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } else {
                showError("Nothing was recorded.")
            }
        }
    }

    private func reset() {
        isRecording = false
        isPaused = false
        stopping = false
        pauseBegan = nil
        frameWindow?.orderOut(nil)
        frameWindow = nil
        controller?.close()
        controller = nil
        stream = nil
        url = nil
    }

    private func showError(_ text: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Recording problem"
        alert.informativeText = text
        alert.runModal()
    }

    private func fail(_ error: Error) {
        reset()
        onChange?()
        showError(error.localizedDescription)
    }

    // MARK: Sample handling (runs on `queue`)

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard sampleBuffer.isValid else { return }
        if type == .screen {
            handleVideo(sampleBuffer)
        } else if #available(macOS 15.0, *), type == .microphone {
            handleAudio(sampleBuffer)
        }
    }

    private func handleVideo(_ sb: CMSampleBuffer) {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sb, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let raw = attachments.first?[.status] as? Int, SCFrameStatus(rawValue: raw) == .complete, !qPaused else { return }
        if !started {
            // Wait briefly for the first microphone buffer so the audio track can match its format.
            if wantsMic, audioFormat == nil, Date().timeIntervalSince(streamStart) < 1.5 { return }
            guard startWriter(at: CMSampleBufferGetPresentationTimeStamp(sb)) else { return }
        }
        guard let input = videoInput, writer?.status == .writing, input.isReadyForMoreMediaData, let out = retimed(sb) else { return }
        input.append(out)
    }

    private func handleAudio(_ sb: CMSampleBuffer) {
        if !started {
            if audioFormat == nil { audioFormat = CMSampleBufferGetFormatDescription(sb) }
            return
        }
        guard let input = audioInput, !qPaused, !qMuted, writer?.status == .writing, input.isReadyForMoreMediaData,
              let out = retimed(sb), CMTimeCompare(CMSampleBufferGetPresentationTimeStamp(out), sessionStart) >= 0 else { return }
        input.append(out)
    }

    private func startWriter(at pts: CMTime) -> Bool {
        guard let url = outputURL, let w = try? AVAssetWriter(outputURL: url, fileType: .mov) else { return false }
        let vi = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height,
        ])
        vi.expectsMediaDataInRealTime = true
        guard w.canAdd(vi) else { return false }
        w.add(vi)
        if wantsMic, let fmt = audioFormat, let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(fmt)?.pointee {
            let ai = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: asbd.mSampleRate,
                AVNumberOfChannelsKey: Int(asbd.mChannelsPerFrame),
                AVEncoderBitRateKey: 96_000,
            ], sourceFormatHint: fmt)
            ai.expectsMediaDataInRealTime = true
            if w.canAdd(ai) { w.add(ai); audioInput = ai }
        }
        guard w.startWriting() else { return false }
        w.startSession(atSourceTime: pts)
        writer = w
        videoInput = vi
        sessionStart = pts
        started = true
        return true
    }

    /// Shifts a buffer's timestamps back by the total time spent paused so the video has no gap.
    private func retimed(_ sb: CMSampleBuffer) -> CMSampleBuffer? {
        if CMTimeCompare(offset, .zero) == 0 { return sb }
        var count: CMItemCount = 0
        CMSampleBufferGetSampleTimingInfoArray(sb, entryCount: 0, arrayToFill: nil, entriesNeededOut: &count)
        var infos = [CMSampleTimingInfo](repeating: CMSampleTimingInfo(), count: count)
        CMSampleBufferGetSampleTimingInfoArray(sb, entryCount: count, arrayToFill: &infos, entriesNeededOut: &count)
        for i in infos.indices {
            infos[i].presentationTimeStamp = CMTimeSubtract(infos[i].presentationTimeStamp, offset)
            if infos[i].decodeTimeStamp.isValid { infos[i].decodeTimeStamp = CMTimeSubtract(infos[i].decodeTimeStamp, offset) }
        }
        var out: CMSampleBuffer?
        CMSampleBufferCreateCopyWithNewTiming(allocator: kCFAllocatorDefault, sampleBuffer: sb, sampleTimingEntryCount: count,
                                              sampleTimingArray: &infos, sampleBufferOut: &out)
        return out
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async { if self.isRecording { self.stop() } }
    }
}

// MARK: - Capture controller

final class CaptureController {
    static let shared = CaptureController()
    var windows: [OverlayWindow] = []

    func grab(displayIndex: Int) -> NSImage? {
        let path = NSTemporaryDirectory() + "snapshot-\(UUID().uuidString).png"
        defer { try? FileManager.default.removeItem(atPath: path) }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        p.arguments = ["-x", "-D", "\(displayIndex)", path]
        do { try p.run() } catch { return nil }
        p.waitUntilExit()
        return NSImage(contentsOfFile: path)
    }

    func ensurePermission() -> Bool {
        if CGPreflightScreenCaptureAccess() { return true }
        CGRequestScreenCaptureAccess()
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Snapshot needs Screen Recording access"
        alert.informativeText = "Enable Snapshot in System Settings → Privacy & Security → Screen Recording, then quit and reopen Snapshot."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
        return false
    }

    func begin() {
        guard windows.isEmpty, !Recorder.shared.isRecording, ensurePermission() else { return }
        var shots: [(NSScreen, NSImage)] = []
        for (i, screen) in NSScreen.screens.enumerated() {
            if let img = grab(displayIndex: i + 1) { shots.append((screen, img)) }
        }
        guard !shots.isEmpty else { return }
        for (screen, img) in shots {
            let pixels = (img.representations.first?.pixelsWide).map(CGFloat.init) ?? screen.frame.width
            let w = OverlayWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            w.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
            w.isOpaque = false
            w.backgroundColor = .clear
            w.hasShadow = false
            w.isReleasedWhenClosed = false
            let view = CaptureView(frame: CGRect(origin: .zero, size: screen.frame.size), image: img, scale: pixels / screen.frame.width)
            w.contentView = view
            w.setFrame(screen.frame, display: true)
            w.makeKeyAndOrderFront(nil)
            w.makeFirstResponder(view)
            windows.append(w)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func finish() {
        let ws = windows
        windows = []
        ws.forEach { $0.orderOut(nil) }
    }

    func fullScreen() {
        guard ensurePermission() else { return }
        let path = NSTemporaryDirectory() + "snapshot-full.png"
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        p.arguments = ["-x", path]
        try? p.run()
        p.waitUntilExit()
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return }
        try? FileManager.default.removeItem(atPath: path)
        Output.save(png: data)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setData(data, forType: .png)
    }
}

// MARK: - App

var hotKeyRef: EventHotKeyRef?

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var idleMenu: NSMenu?
    var tickTimer: Timer?
    var recordingStart = Date()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let icon = NSImage(systemSymbolName: "viewfinder", accessibilityDescription: "Snapshot")
        icon?.isTemplate = true
        statusItem.button?.image = icon
        statusItem.button?.toolTip = "Snapshot — capture screenshots (⌥⇧A)"

        let menu = NSMenu()
        let cap = menu.addItem(withTitle: "Capture Area", action: #selector(captureArea), keyEquivalent: "a")
        cap.keyEquivalentModifierMask = [.option, .shift]
        menu.addItem(withTitle: "Capture Full Screen", action: #selector(captureFull), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Open Save Folder", action: #selector(openFolder), keyEquivalent: "")
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Snapshot", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let tips = [
            "Capture Area": "Drag to select a region, then annotate, copy, save or record it (⌥⇧A)",
            "Capture Full Screen": "Capture the whole main display to the clipboard and your save folder",
            "Open Save Folder": "Open the folder where screenshots and recordings are saved",
            "Settings…": "Choose where screenshots and recordings are saved",
            "Quit Snapshot": "Quit Snapshot and remove it from the menu bar",
        ]
        menu.items.forEach { $0.toolTip = tips[$0.title] }
        menu.items.forEach { $0.target = $0.action == #selector(NSApplication.terminate(_:)) ? NSApp : self }
        statusItem.menu = menu
        idleMenu = menu
        Recorder.shared.onChange = { [weak self] in self?.recordingChanged() }

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async {
                if Recorder.shared.isRecording { Recorder.shared.stop() } else { CaptureController.shared.begin() }
            }
            return noErr
        }, 1, &spec, nil, nil)
        RegisterEventHotKey(UInt32(kVK_ANSI_A), UInt32(optionKey | shiftKey), EventHotKeyID(signature: 0x534E4150, id: 1),
                            GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    // Delay so the menu closes before the screen is grabbed.
    @objc func captureArea() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { CaptureController.shared.begin() }
    }

    @objc func captureFull() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { CaptureController.shared.fullScreen() }
    }

    func recordingChanged() {
        guard let button = statusItem.button else { return }
        if Recorder.shared.isRecording {
            statusItem.length = NSStatusItem.variableLength
            statusItem.menu = nil
            button.target = self
            button.imagePosition = .imageLeading
            button.action = #selector(stopRecording)
            button.image = NSImage(systemSymbolName: "stop.circle.fill", accessibilityDescription: "Stop recording")
            button.image?.isTemplate = false
            button.contentTintColor = .systemRed
            button.toolTip = "Stop Recording (⌥⇧A)"
            recordingStart = Date()
            tickTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.tick() }
            tick()
        } else {
            tickTimer?.invalidate()
            button.title = ""
            button.contentTintColor = nil
            button.action = nil
            let icon = NSImage(systemSymbolName: "viewfinder", accessibilityDescription: "Snapshot")
            icon?.isTemplate = true
            button.image = icon
            button.toolTip = "Snapshot — capture screenshots (⌥⇧A)"
            statusItem.menu = idleMenu
        }
    }

    func tick() {
        let t = Int(Date().timeIntervalSince(recordingStart))
        statusItem.button?.title = String(format: " Stop Recording  %d:%02d", t / 60, t % 60)
    }

    @objc func stopRecording() { Recorder.shared.stop() }

    @objc func openSettings() { SettingsController.shared.show() }

    @objc func openFolder() { NSWorkspace.shared.open(Output.folder) }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
