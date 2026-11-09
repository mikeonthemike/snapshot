import Cocoa

extension ToolSpec {
    /// Replaces the area with coarse blocks of the underlying screenshot, to hide sensitive information.
    static let pixelate = ToolSpec(tool: .pixelate, symbol: "square.grid.3x3.fill", title: "Pixelate (hide sensitive info)", interaction: .drag) { a, ctx in
        guard let first = a.points.first, let last = a.points.last else { return }
        let area = CGRect.spanning(first, last)
        guard area.width >= 1, area.height >= 1 else { return }
        guard let source = ctx.source, ctx.bounds.width > 0 else {
            NSColor.gray.setFill()
            area.fill()
            return
        }
        // The screenshot is drawn into `bounds`, so this is pixels per view point.
        let k = CGFloat(source.width) / ctx.bounds.width
        let pixelArea = CGRect(x: area.minX * k, y: area.minY * k, width: area.width * k, height: area.height * k)
        guard let out = Pixelator.pixelated(source, rect: pixelArea, blockSize: max(Int((Pixelator.blockPoints * k).rounded()), 2)) else { return }
        NSImage(cgImage: out, size: area.size)
            .draw(in: area, from: .zero, operation: .copy, fraction: 1, respectFlipped: true,
                  hints: [.interpolation: NSImageInterpolation.none])
    }
}
