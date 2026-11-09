import Cocoa

/// The menu bar item: the idle menu, the delayed-capture countdown, and the "stop recording" button
/// that replaces the menu while a recording is running.
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private var idleMenu: NSMenu?
    private var tickTimer: Timer?
    private var recordingStart = Date()
    private var captureItem: NSMenuItem!
    private var fullItem: NSMenuItem!
    private var textItem: NSMenuItem!
    private var windowItem: NSMenuItem!
    /// Rebuilt each time it opens; see `MenuBarController+History.swift`.
    let historyMenu = NSMenu(title: "Recent Captures")
    private var countingDown = false

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        statusItem.button?.image = Self.idleIcon()
        statusItem.button?.toolTip = "Snapshot — capture screenshots"
        let menu = buildMenu()
        statusItem.menu = menu
        idleMenu = menu
    }

    private static func idleIcon() -> NSImage? {
        let icon = NSImage(systemSymbolName: "viewfinder", accessibilityDescription: "Snapshot")
        icon?.isTemplate = true
        return icon
    }

    // MARK: Menu

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        captureItem = menu.addItem(withTitle: "Capture Area", action: #selector(captureArea), keyEquivalent: "")
        fullItem = menu.addItem(withTitle: "Capture Full Screen", action: #selector(captureFull), keyEquivalent: "")
        windowItem = menu.addItem(withTitle: "Capture Window", action: #selector(captureWindow), keyEquivalent: "")
        textItem = menu.addItem(withTitle: "Copy Text from Screen", action: #selector(copyText), keyEquivalent: "")
        let delayItem = NSMenuItem(title: "Capture After Delay", action: nil, keyEquivalent: "")
        let delayMenu = NSMenu()
        for secs in [3, 5] {
            for (name, sel) in [("Area", #selector(delayedArea(_:))), ("Full Screen", #selector(delayedFull(_:)))] {
                let it = delayMenu.addItem(withTitle: "\(name) in \(secs) seconds", action: sel, keyEquivalent: "")
                it.tag = secs
                it.target = self
            }
            if secs == 3 { delayMenu.addItem(.separator()) }
        }
        delayItem.submenu = delayMenu
        delayItem.toolTip = "Wait a few seconds before capturing, so you can open a menu or hover state first"
        menu.addItem(delayItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Record Video", action: #selector(recordArea), keyEquivalent: "")
        let recDelayItem = NSMenuItem(title: "Record Video After Delay", action: nil, keyEquivalent: "")
        let recDelayMenu = NSMenu()
        for secs in [3, 5] {
            let it = recDelayMenu.addItem(withTitle: "In \(secs) seconds", action: #selector(delayedRecord(_:)), keyEquivalent: "")
            it.tag = secs
            it.target = self
        }
        recDelayItem.submenu = recDelayMenu
        recDelayItem.toolTip = "Wait a few seconds, then select the area to record"
        menu.addItem(recDelayItem)
        menu.addItem(.separator())
        let historyItem = NSMenuItem(title: "Recent Captures", action: nil, keyEquivalent: "")
        historyMenu.delegate = self
        historyItem.submenu = historyMenu
        menu.addItem(historyItem)
        menu.addItem(withTitle: "Open Save Folder", action: #selector(openFolder), keyEquivalent: "")
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Snapshot", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let tips = [
            "Capture Area": "Drag to select a region, then annotate, copy, save or record it",
            "Record Video": "Select an area, adjust it, then start recording (Return or the record button)",
            "Capture Full Screen": "Capture the whole main display to the clipboard and your save folder",
            "Capture Window": "Click a window to capture it on its own, to the clipboard and your save folder",
            "Copy Text from Screen": "Select an area and copy the text in it to the clipboard",
            "Recent Captures": "Copy, pin or save one of your last few captures",
            "Open Save Folder": "Open the folder where screenshots and recordings are saved",
            "Settings…": "Choose where screenshots and recordings are saved",
            "Quit Snapshot": "Quit Snapshot and remove it from the menu bar",
        ]
        menu.items.forEach { $0.toolTip = tips[$0.title] }
        menu.items.forEach { $0.target = $0.action == #selector(NSApplication.terminate(_:)) ? NSApp : self }
        return menu
    }

    /// Shows the current shortcuts in the menu and tooltips.
    func applyHotkeys() {
        let cap = HotKeys.shared.binding(.capture), full = HotKeys.shared.binding(.fullScreen)
        let text = HotKeys.shared.binding(.copyText), win = HotKeys.shared.binding(.captureWindow)
        for (item, hk) in [(captureItem!, cap), (fullItem!, full), (textItem!, text), (windowItem!, win)] {
            item.keyEquivalent = hk.menuKey
            item.keyEquivalentModifierMask = hk.menuMask
        }
        captureItem.toolTip = "Drag to select a region, then annotate, copy, save or record it (\(cap.display))"
        fullItem.toolTip = "Capture the whole main display to the clipboard and your save folder (\(full.display))"
        windowItem.toolTip = "Click a window to capture it on its own, to the clipboard and your save folder (\(win.display))"
        textItem.toolTip = "Select an area and copy the text in it to the clipboard (\(text.display))"
        if !Recorder.shared.isRecording {
            statusItem.button?.toolTip = "Snapshot — capture screenshots (\(cap.display))"
        }
    }

    // MARK: Capture actions

    // Delay so the menu closes before the screen is grabbed.
    @objc private func captureArea() {
        guard !countingDown else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { CaptureController.shared.begin() }
    }

    @objc private func recordArea() {
        guard !countingDown else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { CaptureController.shared.begin(mode: .video) }
    }

    @objc private func captureWindow() {
        guard !countingDown else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { CaptureController.shared.beginWindowPick() }
    }

    @objc private func copyText() {
        guard !countingDown else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { CaptureController.shared.begin(mode: .text) }
    }

    @objc private func captureFull() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { CaptureController.shared.fullScreen() }
    }

    @objc private func delayedArea(_ sender: NSMenuItem) { countdown(sender.tag) { CaptureController.shared.begin() } }
    @objc private func delayedFull(_ sender: NSMenuItem) { countdown(sender.tag) { CaptureController.shared.fullScreen() } }
    @objc private func delayedRecord(_ sender: NSMenuItem) { countdown(sender.tag) { CaptureController.shared.begin(mode: .video) } }

    /// Counts down in the menu bar, clears the title, then runs `action` once the bar is clean.
    private func countdown(_ seconds: Int, then action: @escaping () -> Void) {
        guard !countingDown, !Recorder.shared.isRecording, ScreenCapturePermission.ensure() else { return }
        countingDown = true
        var remaining = seconds
        statusItem.length = NSStatusItem.variableLength
        statusItem.button?.title = " \(remaining)"
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            remaining -= 1
            if remaining > 0 {
                self.statusItem.button?.title = " \(remaining)"
                return
            }
            t.invalidate()
            self.statusItem.button?.title = ""
            self.statusItem.length = NSStatusItem.squareLength
            self.countingDown = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: action)
        }
    }

    // MARK: Recording state

    /// Swaps the menu for a "Stop Recording" button (with a running timer) while recording, and back again after.
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
            button.toolTip = "Stop Recording (\(HotKeys.shared.binding(.capture).display))"
            recordingStart = Date()
            tickTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.tick() }
            tick()
        } else {
            tickTimer?.invalidate()
            button.title = ""
            button.contentTintColor = nil
            button.action = nil
            button.image = Self.idleIcon()
            applyHotkeys()
            statusItem.menu = idleMenu
        }
    }

    private func tick() {
        let t = Int(Date().timeIntervalSince(recordingStart))
        statusItem.button?.title = String(format: " Stop Recording  %d:%02d", t / 60, t % 60)
    }

    @objc private func stopRecording() { Recorder.shared.stop() }

    // MARK: Other menu items

    @objc private func openSettings() { SettingsController.shared.show() }

    @objc private func openFolder() { NSWorkspace.shared.open(Output.folder) }
}
