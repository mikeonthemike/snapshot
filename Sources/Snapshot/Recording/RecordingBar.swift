import Cocoa

/// Floating bar shown beside the recorded area: timer, pause/resume, mic, discard and stop.
final class RecordingBar: NSObject {
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

        let fx = makeHUDContainer(around: stack, cornerRadius: 12, appearance: NSAppearance(named: .vibrantDark))
        let size = fx.frame.size
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
