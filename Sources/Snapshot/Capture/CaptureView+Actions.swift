import Cocoa

// Turning the selection into output. Rendering happens here; what to do with the result is the delegate's job.
extension CaptureView {
    /// The selected region with annotations, at full pixel resolution.
    func render() -> NSBitmapImageRep? {
        guard let sel = selection else { return nil }
        commitText()
        let w = Int(sel.width * scale), h = Int(sel.height * scale)
        guard let ctx = CGContext(
            data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: scale, y: -scale)
        ctx.translateBy(x: -sel.minX, y: -sel.minY)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
        image.draw(in: bounds, from: .zero, operation: .copy, fraction: 1, respectFlipped: true, hints: nil)
        annotations.forEach { $0.draw() }
        NSGraphicsContext.restoreGraphicsState()
        return ctx.makeImage().map { NSBitmapImageRep(cgImage: $0) }
    }

    private func renderPNG() -> Data? {
        render()?.representation(using: .png, properties: [:])
    }

    @objc func copyImage() {
        guard let png = renderPNG() else { return }
        delegate?.captureView(self, didCopy: png)
    }

    @objc func save() {
        guard let png = renderPNG() else { return }
        delegate?.captureView(self, didSave: png)
    }

    @objc func pin() {
        guard let sel = selection, let win = window, let screen = win.screen, let rep = render() else { return }
        let img = NSImage(size: sel.size)
        img.addRepresentation(rep)
        // View coordinates are flipped and screen-relative; convert to global AppKit coordinates.
        let frame = NSRect(x: screen.frame.minX + sel.minX, y: screen.frame.maxY - sel.maxY, width: sel.width, height: sel.height)
        delegate?.captureView(self, didPin: img, at: frame)
    }

    @objc func record() {
        guard let sel = selection, let win = window, let screen = win.screen else { return }
        commitText()
        let id = screen.displayID ?? CGMainDisplayID()
        let rect = CGRect(x: sel.minX.rounded(), y: sel.minY.rounded(), width: sel.width.rounded(), height: sel.height.rounded())
        delegate?.captureView(self, didRequestRecordingOn: id, rect: rect, scale: scale)
    }
}
