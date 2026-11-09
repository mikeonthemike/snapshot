import Cocoa

/// The magnifier: a zoomed block of screenshot pixels with a crosshair on the centre pixel and the cursor's
/// coordinates underneath. Mouse-transparent, so it never gets in the way of selecting.
final class LoupeView: NSView {
    private var crop: CGImage?
    /// Where the centre pixel sits inside the crop, in crop pixels.
    private var centre = CGPoint.zero
    private var label = ""

    private static let labelHeight: CGFloat = 22
    private static let gap: CGFloat = 6

    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override init(frame: NSRect) {
        super.init(frame: NSRect(origin: .zero, size: LoupeView.fittingSize))
    }

    required init?(coder: NSCoder) { fatalError() }

    static var fittingSize: CGSize {
        CGSize(width: LoupeGeometry.boxSize, height: LoupeGeometry.boxSize + gap + labelHeight)
    }

    /// Shows `source` around `pixel` (source pixel coordinates), captioned with `label`.
    func show(source: CGImage, pixel: (x: Int, y: Int), label: String) {
        let rect = LoupeGeometry.cropRect(centeredOn: pixel, imageWidth: source.width, imageHeight: source.height)
        crop = source.cropping(to: rect)
        centre = CGPoint(x: CGFloat(pixel.x) - rect.minX, y: CGFloat(pixel.y) - rect.minY)
        self.label = label
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let box = CGRect(x: 0, y: 0, width: LoupeGeometry.boxSize, height: LoupeGeometry.boxSize)
        let shape = NSBezierPath(roundedRect: box, xRadius: 8, yRadius: 8)

        NSGraphicsContext.saveGraphicsState()
        shape.addClip()
        if let crop = crop {
            let size = CGSize(width: CGFloat(crop.width) * LoupeGeometry.zoom, height: CGFloat(crop.height) * LoupeGeometry.zoom)
            NSImage(cgImage: crop, size: size).draw(in: CGRect(origin: .zero, size: size), from: .zero, operation: .copy,
                                                    fraction: 1, respectFlipped: true,
                                                    hints: [.interpolation: NSImageInterpolation.none])
            drawGrid(in: size)
        } else {
            NSColor.black.setFill()
            box.fill()
        }
        NSGraphicsContext.restoreGraphicsState()

        // Crosshair: a cell outline in black with a white halo, so it shows on any colour.
        let z = LoupeGeometry.zoom
        let cell = CGRect(x: centre.x * z, y: centre.y * z, width: z, height: z)
        NSColor.white.setStroke()
        let outer = NSBezierPath(rect: cell.insetBy(dx: -1, dy: -1))
        outer.lineWidth = 1.5
        outer.stroke()
        NSColor.black.setStroke()
        let inner = NSBezierPath(rect: cell.insetBy(dx: 0.5, dy: 0.5))
        inner.lineWidth = 1
        inner.stroke()

        NSColor.white.setStroke()
        shape.lineWidth = 2
        shape.stroke()

        drawLabel()
    }

    private func drawGrid(in size: CGSize) {
        NSColor.black.withAlphaComponent(0.18).setStroke()
        let path = NSBezierPath()
        path.lineWidth = 0.5
        var p = LoupeGeometry.zoom
        while p < size.width {
            path.move(to: CGPoint(x: p, y: 0)); path.line(to: CGPoint(x: p, y: size.height))
            p += LoupeGeometry.zoom
        }
        p = LoupeGeometry.zoom
        while p < size.height {
            path.move(to: CGPoint(x: 0, y: p)); path.line(to: CGPoint(x: size.width, y: p))
            p += LoupeGeometry.zoom
        }
        path.stroke()
    }

    private func drawLabel() {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium), .foregroundColor: NSColor.white,
        ]
        let text = label as NSString
        let size = text.size(withAttributes: attrs)
        let pill = CGRect(x: (bounds.width - size.width - 14) / 2, y: LoupeGeometry.boxSize + Self.gap,
                          width: size.width + 14, height: Self.labelHeight)
        NSColor.black.withAlphaComponent(0.75).setFill()
        NSBezierPath(roundedRect: pill, xRadius: 6, yRadius: 6).fill()
        text.draw(at: CGPoint(x: pill.minX + 7, y: pill.minY + (pill.height - size.height) / 2), withAttributes: attrs)
    }
}
