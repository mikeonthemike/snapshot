import Cocoa
import Carbon.HIToolbox

/// A button that records the next key combination pressed.
final class HotKeyField: NSButton {
    let slot: HotKeyAction
    var onChange: (() -> Void)?
    private var monitor: Any?

    init(slot: HotKeyAction) {
        self.slot = slot
        super.init(frame: .zero)
        bezelStyle = .rounded
        target = self
        action = #selector(toggle)
        widthAnchor.constraint(equalToConstant: 130).isActive = true
        refresh()
    }

    required init?(coder: NSCoder) { fatalError() }

    func refresh() {
        title = monitor != nil ? "Press shortcut…" : HotKeys.shared.binding(slot).display
    }

    @objc private func toggle() { monitor == nil ? begin() : cancel() }

    private func begin() {
        HotKeys.shared.unregisterAll()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event)
            return nil
        }
        refresh()
    }

    private func handle(_ event: NSEvent) {
        if event.keyCode == 53 { cancel(); return }
        let mods = HotKey.carbonModifiers(event.modifierFlags.intersection(.deviceIndependentFlagsMask))
        // Require ⌘, ⌥ or ⌃ so the shortcut doesn't swallow normal typing.
        guard mods & UInt32(cmdKey | optionKey | controlKey) != 0 else { NSSound.beep(); return }
        let hk = HotKey(keyCode: UInt32(event.keyCode), modifiers: mods, key: HotKey.label(for: event))
        if let other = HotKeyAction.allCases.first(where: { $0 != slot && HotKeys.shared.binding($0) == hk }) {
            NSSound.beep()
            toolTip = "Already used for “\(other.title)”"
            return
        }
        toolTip = nil
        endRecording()
        HotKeys.shared.set(hk, for: slot)
        refresh()
        onChange?()
    }

    func cancel() {
        guard monitor != nil else { return }
        endRecording()
        HotKeys.shared.registerAll()
        refresh()
        onChange?()
    }

    private func endRecording() {
        if let m = monitor { NSEvent.removeMonitor(m) }
        monitor = nil
    }
}
