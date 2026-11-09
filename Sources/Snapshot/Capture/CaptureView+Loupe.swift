import Cocoa

// The magnifier shown while ⌥ is held, to place selection edges pixel-perfectly.
extension CaptureView {
    /// Shows, moves or hides the loupe to match the ⌥ key and the pointer. Cheap enough to call on every mouse move.
    func updateLoupe(at point: CGPoint? = nil) {
        guard NSEvent.modifierFlags.contains(.option), textField == nil, let source = sourceImage, let win = window else {
            loupe?.isHidden = true
            return
        }
        let p = point ?? convert(win.mouseLocationOutsideOfEventStream, from: nil)
        guard bounds.contains(p) else {
            loupe?.isHidden = true
            return
        }
        let view: LoupeView
        if let existing = loupe {
            view = existing
        } else {
            view = LoupeView(frame: .zero)
            loupe = view
        }
        // Keep it above the selection and toolbar.
        if view.superview !== self || subviews.last !== view { addSubview(view, positioned: .above, relativeTo: nil) }

        let k = CGFloat(source.width) / max(bounds.width, 1)
        let pixel = LoupeGeometry.pixel(at: p, scale: k, width: source.width, height: source.height)
        view.show(source: source, pixel: pixel, label: "\(Int(p.x.rounded(.down))), \(Int(p.y.rounded(.down)))")
        view.frame.origin = LoupeGeometry.origin(for: view.frame.size, cursor: p, bounds: bounds)
        view.isHidden = false
    }
}
