import Cocoa

/// Where a tooltip goes relative to the control it describes. Pure, so it can be tested.
enum TooltipPlacement {
    static let gap: CGFloat = 6

    /// Below `anchor` by default; above it when there's no room below. Always kept inside `visible`.
    /// All rectangles are in screen coordinates (bottom-left origin).
    static func origin(for size: CGSize, anchor: CGRect, visible: CGRect) -> CGPoint {
        var y = anchor.minY - gap - size.height
        if y < visible.minY + 4 { y = anchor.maxY + gap }
        y = min(y, visible.maxY - size.height - 4)
        var x = anchor.midX - size.width / 2
        x = min(max(x, visible.minX + 4), visible.maxX - size.width - 4)
        return CGPoint(x: x, y: y)
    }
}

/// A small dark label window shown above whatever window owns the control. Native tooltips are drawn well below
/// our full-screen overlay and the recording bar, so those need their own.
final class TooltipWindow {
    static let shared = TooltipWindow()

    private let panel: NSPanel
    private let label = NSTextField(labelWithString: "")
    private weak var parent: NSWindow?

    private init() {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        label.font = .systemFont(ofSize: 12)
        label.textColor = .white
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 3
        label.preferredMaxLayoutWidth = 260

        let box = NSView()
        box.wantsLayer = true
        box.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.88).cgColor
        box.layer?.cornerRadius = 6
        label.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: box.topAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -4),
        ])
        panel.contentView = box
    }

    /// Shows `text` near `anchor` (screen coordinates), above `owner` in the window stack.
    func show(_ text: String, near anchor: CGRect, above owner: NSWindow) {
        hide()
        label.stringValue = text
        guard let box = panel.contentView else { return }
        let size = box.fittingSize
        let screen = owner.screen ?? NSScreen.main
        let visible = screen?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
        panel.setFrame(CGRect(origin: TooltipPlacement.origin(for: size, anchor: anchor, visible: visible), size: size), display: true)
        parent = owner
        owner.addChildWindow(panel, ordered: .above)
        panel.level = NSWindow.Level(rawValue: min(owner.level.rawValue + 1, Int(Int32.max)))
        panel.orderFront(nil)
    }

    func hide() {
        parent?.removeChildWindow(panel)
        parent = nil
        panel.orderOut(nil)
    }
}

/// A button whose tooltip is drawn by `TooltipWindow`, so it is visible over full-screen overlays.
final class TipButton: NSButton {
    var tip: String?
    private var pending: DispatchWorkItem?
    private static let delay: TimeInterval = 0.4

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    override func mouseEntered(with event: NSEvent) {
        cancel()
        guard tip?.isEmpty == false else { return }
        let work = DispatchWorkItem { [weak self] in self?.showTip() }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.delay, execute: work)
    }

    override func mouseExited(with event: NSEvent) { cancel() }

    override func mouseDown(with event: NSEvent) {
        cancel()
        super.mouseDown(with: event)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { cancel() }
    }

    override func viewDidHide() {
        super.viewDidHide()
        cancel()
    }

    deinit { pending?.cancel() }

    private func showTip() {
        guard let tip = tip, let w = window, w.isVisible, !isHiddenOrHasHiddenAncestor else { return }
        let anchor = w.convertToScreen(convert(bounds, to: nil))
        TooltipWindow.shared.show(tip, near: anchor, above: w)
    }

    private func cancel() {
        pending?.cancel()
        pending = nil
        TooltipWindow.shared.hide()
    }
}
