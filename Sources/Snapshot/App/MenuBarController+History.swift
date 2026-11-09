import Cocoa

// The "Recent Captures" submenu: a thumbnail per remembered capture, each with its own actions.
extension MenuBarController: NSMenuDelegate {
    private static let thumbnailPoints: CGFloat = 72

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === historyMenu else { return }
        rebuildHistoryMenu()
    }

    private func rebuildHistoryMenu() {
        historyMenu.removeAllItems()
        let entries = CaptureHistory.shared.entries
        guard !entries.isEmpty else {
            let empty = historyMenu.addItem(withTitle: Preferences.keepHistory ? "No recent captures" : "History is turned off in Settings",
                                            action: nil, keyEquivalent: "")
            empty.isEnabled = false
            return
        }
        for entry in entries {
            let item = NSMenuItem(title: Self.title(for: entry), action: nil, keyEquivalent: "")
            item.image = Self.thumbnail(for: entry)
            item.submenu = actionsMenu(for: entry)
            historyMenu.addItem(item)
        }
        historyMenu.addItem(.separator())
        historyMenu.addItem(withTitle: "Clear History", action: #selector(clearHistory), keyEquivalent: "").target = self
    }

    private func actionsMenu(for entry: HistoryEntry) -> NSMenu {
        let menu = NSMenu()
        let actions: [(String, Selector)] = [
            ("Copy", #selector(historyCopy(_:))),
            ("Pin to Screen", #selector(historyPin(_:))),
            ("Save to Folder", #selector(historySave(_:))),
        ]
        for (title, action) in actions {
            let item = menu.addItem(withTitle: title, action: action, keyEquivalent: "")
            item.target = self
            item.representedObject = entry.url
        }
        menu.addItem(.separator())
        let remove = menu.addItem(withTitle: "Remove from History", action: #selector(historyRemove(_:)), keyEquivalent: "")
        remove.target = self
        remove.representedObject = entry.url
        return menu
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        f.doesRelativeDateFormatting = true   // "Today, 2:14 PM"
        return f
    }()

    private static func title(for entry: HistoryEntry) -> String {
        let when = dateFormatter.string(from: entry.date)
        guard let size = CaptureHistory.pixelSize(of: entry.url) else { return when }
        return "\(when) · \(Int(size.width))×\(Int(size.height))"
    }

    /// A thumbnail that fits a `thumbnailPoints`-tall box, sharp on Retina.
    private static func thumbnail(for entry: HistoryEntry) -> NSImage? {
        guard let image = CaptureHistory.thumbnail(for: entry.url, maxPixelSize: Int(thumbnailPoints * 2 * 1.6)) else { return nil }
        let aspect = image.size.width / max(image.size.height, 1)
        let height = min(thumbnailPoints, thumbnailPoints / max(aspect, 1))
        image.size = NSSize(width: height * aspect, height: height)
        return image
    }

    // MARK: Actions

    private func data(from sender: NSMenuItem) -> Data? {
        (sender.representedObject as? URL).flatMap { try? Data(contentsOf: $0) }
    }

    @objc private func historyCopy(_ sender: NSMenuItem) {
        guard let png = data(from: sender) else { return NSSound.beep() }
        Pasteboard.copy(png: png)
    }

    @objc private func historySave(_ sender: NSMenuItem) {
        guard let png = data(from: sender) else { return NSSound.beep() }
        Output.save(png: png)
    }

    @objc private func historyPin(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL, let image = NSImage(contentsOf: url),
              let rep = image.representations.first else { return NSSound.beep() }
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let natural = CGSize(width: CGFloat(rep.pixelsWide) / screen.backingScaleFactor,
                             height: CGFloat(rep.pixelsHigh) / screen.backingScaleFactor)
        let size = PinPlacement.fittedSize(natural, in: screen.visibleFrame.size)
        image.size = size
        let frame = NSRect(x: screen.visibleFrame.midX - size.width / 2, y: screen.visibleFrame.midY - size.height / 2,
                           width: size.width, height: size.height)
        PinWindow.pin(image, at: frame)
    }

    @objc private func historyRemove(_ sender: NSMenuItem) {
        if let url = sender.representedObject as? URL { CaptureHistory.shared.remove(url) }
    }

    @objc private func clearHistory() { CaptureHistory.shared.clear() }
}

/// How a pinned history image is sized when it first appears.
enum PinPlacement {
    /// `natural` scaled down (never up) to fit within `fraction` of `available`, keeping its aspect ratio.
    static func fittedSize(_ natural: CGSize, in available: CGSize, fraction: CGFloat = 0.7) -> CGSize {
        guard natural.width > 0, natural.height > 0 else { return natural }
        let scale = min(1, available.width * fraction / natural.width, available.height * fraction / natural.height)
        return CGSize(width: natural.width * scale, height: natural.height * scale)
    }
}
