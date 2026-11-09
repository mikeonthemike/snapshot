import Cocoa

// The floating toolbar beside the selection and the tool/colour/undo actions behind it.
extension CaptureView {
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
        var views: [NSView] = []
        for (i, spec) in AnnotationTools.all.enumerated() {
            let b = button(spec.symbol, spec.title, #selector(toolTapped(_:)))
            b.tag = i
            toolButtons[spec.tool] = b
            views.append(b)
        }
        let cb = button("circle.fill", "Color", #selector(cycleColor))
        cb.contentTintColor = color
        colorButton = cb
        views.append(cb)
        views.append(button("arrow.uturn.backward", "Undo (⌘Z)", #selector(undo)))
        views.append(button("xmark", "Cancel (Esc)", #selector(cancel)))
        views.append(button("pin", "Pin to screen (⌘P)", #selector(pin)))
        let rec = button(mode == .video ? "record.circle.fill" : "record.circle",
                         mode == .video ? "Record this area (⌘R / Return)" : "Record this area (⌘R)", #selector(record))
        rec.contentTintColor = .systemRed
        views.append(rec)
        let ocr = button("text.viewfinder", mode == .text ? "Copy text (⌘T / Return)" : "Copy text (⌘T)", #selector(copyText))
        if mode == .text { ocr.contentTintColor = .systemBlue }
        views.append(ocr)
        views.append(button("square.and.arrow.down", "Save (⌘S)", #selector(save)))
        views.append(button("doc.on.doc", "Copy (⌘C / Return)", #selector(copyImage)))

        let stack = NSStackView(views: views)
        stack.spacing = 2
        stack.edgeInsets = NSEdgeInsets(top: 4, left: 6, bottom: 4, right: 6)
        let fx = makeHUDContainer(around: stack, cornerRadius: 10)
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
        let t = AnnotationTools.all[sender.tag].tool
        tool = (tool == t) ? .select : t
        updateToolHighlight()
    }

    @objc func cycleColor() {
        let i = annotationPalette.firstIndex(of: color) ?? 0
        color = annotationPalette[(i + 1) % annotationPalette.count]
        colorButton?.contentTintColor = color
    }

    @objc func undo() {
        commitText()
        _ = annotations.popLast()
        needsDisplay = true
    }

    @objc func cancel() { delegate?.captureViewDidCancel(self) }
}
