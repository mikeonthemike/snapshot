import Cocoa

// In-place text annotation editing.
extension CaptureView: NSTextFieldDelegate {
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
}
