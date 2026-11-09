import CoreGraphics

/// Pixelation of an image region. Pure CoreGraphics so it can be unit tested.
enum Pixelator {
    /// Block size in view points for the pixelate tool.
    static let blockPoints: CGFloat = 10

    /// The part of `image` inside `rect` (pixel coordinates, top-left origin), replaced by square blocks of
    /// `blockSize` pixels each holding the average colour of that part. Returns an image the size of the
    /// (integral, clamped) rect, or nil if the rect is empty.
    static func pixelated(_ image: CGImage, rect: CGRect, blockSize: Int) -> CGImage? {
        let r = rect.integral.intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard r.width >= 1, r.height >= 1, blockSize >= 1, let crop = image.cropping(to: r) else { return nil }
        let w = Int(r.width), h = Int(r.height)
        let sw = max(1, Int((CGFloat(w) / CGFloat(blockSize)).rounded(.up)))
        let sh = max(1, Int((CGFloat(h) / CGFloat(blockSize)).rounded(.up)))
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let info = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let down = CGContext(data: nil, width: sw, height: sh, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: info) else { return nil }
        down.interpolationQuality = .high
        down.draw(crop, in: CGRect(x: 0, y: 0, width: sw, height: sh))
        guard let small = down.makeImage(),
              let up = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: info)
        else { return nil }
        up.interpolationQuality = .none
        up.draw(small, in: CGRect(x: 0, y: 0, width: w, height: h))
        return up.makeImage()
    }
}
