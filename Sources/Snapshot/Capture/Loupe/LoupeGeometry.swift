import CoreGraphics

/// Pure geometry for the magnifier shown while holding ⌥: which source pixels to show, and where to put it.
enum LoupeGeometry {
    /// Source pixels across and down. Odd, so there is a single centre pixel under the crosshair.
    static let gridSize = 15
    /// On-screen points per source pixel.
    static let zoom: CGFloat = 10
    /// Side of the magnified square, in points.
    static var boxSize: CGFloat { CGFloat(gridSize) * zoom }

    /// The pixel under `point` (view coordinates). `scale` is source pixels per view point. Clamped to the image.
    static func pixel(at point: CGPoint, scale: CGFloat, width: Int, height: Int) -> (x: Int, y: Int) {
        (min(max(Int((point.x * scale).rounded(.down)), 0), max(width - 1, 0)),
         min(max(Int((point.y * scale).rounded(.down)), 0), max(height - 1, 0)))
    }

    /// The block of source pixels to magnify: `gridSize` square, centred on `pixel` where possible and shifted
    /// to stay inside the image near its edges. Smaller than `gridSize` only if the image itself is.
    static func cropRect(centeredOn pixel: (x: Int, y: Int), imageWidth: Int, imageHeight: Int) -> CGRect {
        let w = min(gridSize, imageWidth), h = min(gridSize, imageHeight)
        let x = min(max(pixel.x - gridSize / 2, 0), imageWidth - w)
        let y = min(max(pixel.y - gridSize / 2, 0), imageHeight - h)
        return CGRect(x: x, y: y, width: w, height: h)
    }

    /// Where to place the loupe (view coordinates, top-left origin): down and to the right of the cursor,
    /// flipping to the other side when it would run off the screen.
    static func origin(for size: CGSize, cursor: CGPoint, bounds: CGRect, offset: CGFloat = 24) -> CGPoint {
        var x = cursor.x + offset
        if x + size.width > bounds.maxX - 4 { x = cursor.x - offset - size.width }
        var y = cursor.y + offset
        if y + size.height > bounds.maxY - 4 { y = cursor.y - offset - size.height }
        x = min(max(x, bounds.minX + 4), bounds.maxX - size.width - 4)
        y = min(max(y, bounds.minY + 4), bounds.maxY - size.height - 4)
        return CGPoint(x: x, y: y)
    }
}
