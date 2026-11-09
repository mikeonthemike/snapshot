import Cocoa

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
