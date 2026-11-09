// Renders the Snapshot app icon (viewfinder + shutter) and writes Resources/AppIcon.icns
import AppKit

func render(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    // macOS icon grid: artwork occupies ~80% of the canvas
    let inset = s * 0.1
    let body = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let radius = body.width * 0.2237
    let path = NSBezierPath(roundedRect: body, xRadius: radius, yRadius: radius)

    // Drop shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.012), blur: s * 0.03,
                  color: NSColor.black.withAlphaComponent(0.35).cgColor)
    NSColor.black.setFill(); path.fill()
    ctx.restoreGState()

    // Gradient background
    ctx.saveGState()
    path.addClip()
    let grad = NSGradient(colors: [NSColor(red: 0.42, green: 0.36, blue: 0.98, alpha: 1),
                                   NSColor(red: 0.13, green: 0.55, blue: 0.98, alpha: 1)])!
    grad.draw(in: body, angle: -60)
    // Soft top highlight
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.22), NSColor.white.withAlphaComponent(0)])!
        .draw(in: CGRect(x: body.minX, y: body.midY, width: body.width, height: body.height / 2), angle: -90)
    ctx.restoreGState()

    // Viewfinder corner brackets
    let white = NSColor.white
    white.setStroke()
    let m = body.width * 0.2          // margin from body edge
    let arm = body.width * 0.17       // bracket arm length
    let lw = body.width * 0.05
    let r = CGRect(x: body.minX + m, y: body.minY + m, width: body.width - 2 * m, height: body.height - 2 * m)
    let br = NSBezierPath()
    br.lineWidth = lw; br.lineCapStyle = .round; br.lineJoinStyle = .round
    func corner(_ x: CGFloat, _ y: CGFloat, _ dx: CGFloat, _ dy: CGFloat) {
        br.move(to: CGPoint(x: x + dx * arm, y: y))
        br.line(to: CGPoint(x: x, y: y))
        br.line(to: CGPoint(x: x, y: y + dy * arm))
    }
    corner(r.minX, r.minY, 1, 1); corner(r.maxX, r.minY, -1, 1)
    corner(r.minX, r.maxY, 1, -1); corner(r.maxX, r.maxY, -1, -1)
    br.stroke()

    // Shutter: ring + solid centre
    let c = CGPoint(x: body.midX, y: body.midY)
    let ringR = body.width * 0.16
    let ring = NSBezierPath(ovalIn: CGRect(x: c.x - ringR, y: c.y - ringR, width: 2 * ringR, height: 2 * ringR))
    ring.lineWidth = lw * 0.8; ring.stroke()
    let dotR = ringR * 0.58
    white.setFill()
    NSBezierPath(ovalIn: CGRect(x: c.x - dotR, y: c.y - dotR, width: 2 * dotR, height: 2 * dotR)).fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let set = "build/AppIcon.iconset"
try? FileManager.default.removeItem(atPath: set)
try! FileManager.default.createDirectory(atPath: set, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! render(base).write(to: URL(fileURLWithPath: "\(set)/icon_\(base)x\(base).png"))
    try! render(base * 2).write(to: URL(fileURLWithPath: "\(set)/icon_\(base)x\(base)@2x.png"))
}
