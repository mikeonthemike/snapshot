import Cocoa

final class SettingsController: NSObject, NSWindowDelegate {
    static let shared = SettingsController()
    private var window: NSWindow?
    private let pathField = NSTextField(labelWithString: "")
    private let loginCheckbox = NSButton(checkboxWithTitle: "Open Snapshot at login", target: nil, action: nil)
    private let loginNote = NSTextField(labelWithString: "")
    private let saveOnCopyCheckbox = NSButton(checkboxWithTitle: "Also save a file when copying a capture", target: nil, action: nil)
    private let shadowCheckbox = NSButton(checkboxWithTitle: "Include shadow in window screenshots", target: nil, action: nil)
    private var fields: [HotKeyField] = []
    private var warnings: [HotKeyAction: NSTextField] = [:]

    func show() {
        if window == nil { build() }
        refresh()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func heading(_ text: String) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = .boldSystemFont(ofSize: 13)
        return l
    }

    private func build() {
        pathField.lineBreakMode = .byTruncatingMiddle
        pathField.font = .systemFont(ofSize: 12)
        pathField.textColor = .secondaryLabelColor
        pathField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        loginCheckbox.target = self
        loginCheckbox.action = #selector(toggleLogin)
        saveOnCopyCheckbox.target = self
        saveOnCopyCheckbox.action = #selector(toggleSaveOnCopy)
        shadowCheckbox.target = self
        shadowCheckbox.action = #selector(toggleShadow)
        loginNote.font = .systemFont(ofSize: 11)
        loginNote.textColor = .systemOrange

        let choose = NSButton(title: "Choose…", target: self, action: #selector(choose))
        let resetFolder = NSButton(title: "Reset to Desktop", target: self, action: #selector(resetFolder))
        let folderButtons = NSStackView(views: [choose, resetFolder])
        folderButtons.spacing = 8

        var rows: [NSView] = []
        for a in HotKeyAction.allCases {
            let label = NSTextField(labelWithString: a.title + ":")
            label.widthAnchor.constraint(equalToConstant: 140).isActive = true
            let field = HotKeyField(slot: a)
            field.onChange = { [weak self] in self?.refresh() }
            fields.append(field)
            let warn = NSTextField(labelWithString: "")
            warn.font = .systemFont(ofSize: 11)
            warn.textColor = .systemOrange
            warnings[a] = warn
            let row = NSStackView(views: [label, field, warn])
            row.spacing = 8
            rows.append(row)
        }
        let resetKeys = NSButton(title: "Reset Shortcuts", target: self, action: #selector(resetKeys))

        let stack = NSStackView(views: [
            heading("General"), loginCheckbox, loginNote, saveOnCopyCheckbox, shadowCheckbox,
            heading("Save screenshots and recordings to:"), pathField, folderButtons,
            heading("Shortcuts"),
        ] + rows + [resetKeys])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.setCustomSpacing(22, after: shadowCheckbox)
        stack.setCustomSpacing(22, after: folderButtons)
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 260),
                         styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = "Snapshot Settings"
        w.isReleasedWhenClosed = false
        w.delegate = self
        w.contentView = stack
        pathField.preferredMaxLayoutWidth = 420
        w.setContentSize(NSSize(width: 460, height: stack.fittingSize.height))
        w.center()
        window = w
    }

    private func refresh() {
        pathField.stringValue = (Output.folder.path as NSString).abbreviatingWithTildeInPath
        fields.forEach { $0.refresh() }
        loginCheckbox.state = LaunchAtLogin.isEnabled ? .on : .off
        saveOnCopyCheckbox.state = Preferences.saveOnCopy ? .on : .off
        shadowCheckbox.state = Preferences.includeWindowShadow ? .on : .off
        loginNote.stringValue = LaunchAtLogin.needsApproval ? "Approve Snapshot in System Settings → General → Login Items" : ""
        for (a, label) in warnings {
            label.stringValue = HotKeys.shared.failed.contains(a) ? "In use by another app" : ""
        }
    }

    func windowWillClose(_ notification: Notification) { fields.forEach { $0.cancel() } }
    func windowDidResignKey(_ notification: Notification) { fields.forEach { $0.cancel() } }

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

    @objc private func toggleSaveOnCopy() {
        Preferences.saveOnCopy = saveOnCopyCheckbox.state == .on
    }

    @objc private func toggleShadow() {
        Preferences.includeWindowShadow = shadowCheckbox.state == .on
    }

    @objc private func toggleLogin() {
        do {
            try LaunchAtLogin.setEnabled(loginCheckbox.state == .on)
        } catch {
            NSSound.beep()
            let alert = NSAlert()
            alert.messageText = "Couldn't change the login item"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
        refresh()
    }

    @objc private func resetFolder() {
        Output.folder = Output.defaultFolder
        refresh()
    }

    @objc private func resetKeys() {
        HotKeyAction.allCases.forEach { HotKeys.shared.set(nil, for: $0) }
        refresh()
    }
}
