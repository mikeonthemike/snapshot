import Cocoa

// Keyboard control of the selection: arrows move it, ⌥+arrows resize it, ⇧ makes the step 10 points.
extension CaptureView {
    /// Moves the selection, taking any annotations with it.
    func moveSelection(to new: CGRect) {
        guard let old = selection else { return }
        selection = new
        let dx = new.minX - old.minX, dy = new.minY - old.minY
        guard dx != 0 || dy != 0 else { return }
        for i in annotations.indices {
            annotations[i].points = annotations[i].points.map { CGPoint(x: $0.x + dx, y: $0.y + dy) }
        }
    }

    /// Handles an arrow-key press. Returns true if it was used.
    func handleArrowKey(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags
        guard !flags.contains(.command), let key = ArrowKey(keyCode: event.keyCode), let s = selection,
              dragStart == nil, activeHandle == nil, moveOrigin == nil, current == nil, textField == nil else { return false }
        let step: CGFloat = flags.contains(.shift) ? 10 : 1
        let dx = key.vector.x * step, dy = key.vector.y * step
        if flags.contains(.option) {
            selection = SelectionGeometry.resized(s, byWidth: dx, height: dy, within: bounds)
        } else {
            moveSelection(to: SelectionGeometry.moved(s, by: CGPoint(x: dx, y: dy), within: bounds))
        }
        positionToolbar()
        needsDisplay = true
        return true
    }
}
