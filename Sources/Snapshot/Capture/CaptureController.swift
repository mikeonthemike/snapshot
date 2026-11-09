import Cocoa

/// Owns the capture overlay windows for one capture session, and carries out what the overlay asks for.
final class CaptureController {
    static let shared = CaptureController()
    private(set) var windows: [OverlayWindow] = []

    func begin(mode: CaptureMode = .image) {
        present { [unowned self] screen, img, scale in
            let view = CaptureView(frame: CGRect(origin: .zero, size: screen.frame.size), image: img, scale: scale)
            view.mode = mode
            view.delegate = self
            return view
        }
    }

    /// Lets the user click a window to capture it.
    func beginWindowPick() {
        let list = WindowList.current()
        present { [unowned self] screen, img, _ in
            let display = CGDisplayBounds(screen.displayID ?? CGMainDisplayID())
            let view = WindowPickerView(frame: CGRect(origin: .zero, size: screen.frame.size), image: img, windows: list, displayBounds: display)
            view.delegate = self
            return view
        }
        windows.compactMap { $0.contentView as? WindowPickerView }.forEach { $0.updateHover() }
    }

    /// Freezes every display behind a full-screen overlay window, each showing the view `makeView` returns.
    private func present(_ makeView: (_ screen: NSScreen, _ image: NSImage, _ scale: CGFloat) -> NSView) {
        guard windows.isEmpty, !Recorder.shared.isRecording, ScreenCapturePermission.ensure() else { return }
        var shots: [(NSScreen, NSImage)] = []
        for (i, screen) in NSScreen.screens.enumerated() {
            if let img = ScreenGrabber.image(ofDisplay: i + 1) { shots.append((screen, img)) }
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
            let view = makeView(screen, img, pixels / screen.frame.width)
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

    /// Captures the main display straight to the clipboard and the save folder.
    func fullScreen() {
        guard ScreenCapturePermission.ensure(), let data = ScreenGrabber.mainDisplayPNG() else { return }
        Output.save(png: data)
        Pasteboard.copy(png: data)
    }
}

extension CaptureController: CaptureViewDelegate {
    func captureViewDidCancel(_ view: CaptureView) { finish() }

    func captureView(_ view: CaptureView, didCopy png: Data) {
        if Preferences.saveOnCopy { Output.save(png: png) }
        Pasteboard.copy(png: png)
        finish()
    }

    func captureView(_ view: CaptureView, didSave png: Data) {
        Output.save(png: png)
        Pasteboard.copy(png: png)
        finish()
    }

    func captureView(_ view: CaptureView, didRequestTextFrom image: CGImage) {
        finish()
        TextCopier.copyText(from: image)
    }

    func captureView(_ view: CaptureView, didPin image: NSImage, at frame: NSRect) {
        finish()
        PinWindow.pin(image, at: frame)
    }

    func captureView(_ view: CaptureView, didRequestRecordingOn displayID: CGDirectDisplayID, rect: CGRect, scale: CGFloat) {
        finish()
        // Give the overlay a moment to disappear before the first frame is captured.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            Recorder.shared.start(displayID: displayID, rect: rect, scale: scale)
        }
    }
}

extension CaptureController: WindowPickerDelegate {
    func windowPickerDidCancel(_ view: WindowPickerView) { finish() }

    func windowPicker(_ view: WindowPickerView, didPick window: WindowInfo) {
        finish()
        // Let the overlay disappear before grabbing.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            guard let png = ScreenGrabber.windowPNG(id: window.id, includeShadow: Preferences.includeWindowShadow) else {
                NSSound.beep()
                return
            }
            Output.save(png: png)
            Pasteboard.copy(png: png)
        }
    }
}
