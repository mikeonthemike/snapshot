import Testing
import Cocoa
@testable import Snapshot

@Suite struct LoupeGeometryTests {
    @Test func boxIsGridTimesZoom() {
        #expect(LoupeGeometry.gridSize % 2 == 1)   // a single centre pixel
        #expect(LoupeGeometry.boxSize == CGFloat(LoupeGeometry.gridSize) * LoupeGeometry.zoom)
    }

    @Test func pixelUnderTheCursorUsesTheScale() {
        #expect(LoupeGeometry.pixel(at: CGPoint(x: 10.4, y: 20.9), scale: 2, width: 1000, height: 1000) == (20, 41))
        #expect(LoupeGeometry.pixel(at: CGPoint(x: 10.4, y: 20.9), scale: 1, width: 1000, height: 1000) == (10, 20))
    }

    @Test func pixelIsClampedToTheImage() {
        #expect(LoupeGeometry.pixel(at: CGPoint(x: -5, y: -5), scale: 2, width: 100, height: 80) == (0, 0))
        #expect(LoupeGeometry.pixel(at: CGPoint(x: 999, y: 999), scale: 2, width: 100, height: 80) == (99, 79))
    }

    @Test func cropIsCentredAwayFromTheEdges() {
        let r = LoupeGeometry.cropRect(centeredOn: (500, 400), imageWidth: 1000, imageHeight: 800)
        let g = CGFloat(LoupeGeometry.gridSize)
        #expect(r.size == CGSize(width: g, height: g))
        #expect(r.midX - 0.5 == 500 && r.midY - 0.5 == 400)   // the centre pixel is the middle cell
    }

    @Test func cropStaysInsideTheImageAtCornersAndKeepsItsSize() {
        let g = CGFloat(LoupeGeometry.gridSize)
        let tl = LoupeGeometry.cropRect(centeredOn: (0, 0), imageWidth: 1000, imageHeight: 800)
        #expect(tl == CGRect(x: 0, y: 0, width: g, height: g))
        let br = LoupeGeometry.cropRect(centeredOn: (999, 799), imageWidth: 1000, imageHeight: 800)
        #expect(br == CGRect(x: 1000 - g, y: 800 - g, width: g, height: g))
    }

    @Test func tinyImagesGiveASmallerCrop() {
        let r = LoupeGeometry.cropRect(centeredOn: (3, 2), imageWidth: 6, imageHeight: 4)
        #expect(r == CGRect(x: 0, y: 0, width: 6, height: 4))
    }

    private let bounds = CGRect(x: 0, y: 0, width: 1440, height: 900)
    private let size = LoupeView.fittingSize

    @Test func placedDownAndRightOfTheCursor() {
        let o = LoupeGeometry.origin(for: size, cursor: CGPoint(x: 300, y: 300), bounds: bounds)
        #expect(o == CGPoint(x: 324, y: 324))
    }

    @Test func flipsLeftAndUpNearTheBottomRightCorner() {
        let c = CGPoint(x: 1400, y: 880)
        let o = LoupeGeometry.origin(for: size, cursor: c, bounds: bounds)
        #expect(o.x + size.width < c.x)      // wholly left of the cursor
        #expect(o.y + size.height < c.y)     // wholly above it
    }

    @Test func alwaysStaysOnScreen() {
        for c in [CGPoint(x: 0, y: 0), CGPoint(x: 1440, y: 0), CGPoint(x: 0, y: 900), CGPoint(x: 1440, y: 900), CGPoint(x: 720, y: 450)] {
            let o = LoupeGeometry.origin(for: size, cursor: c, bounds: bounds)
            #expect(o.x >= 0 && o.y >= 0)
            #expect(o.x + size.width <= bounds.maxX && o.y + size.height <= bounds.maxY)
        }
    }
}

@Suite @MainActor struct LoupeViewTests {
    /// Left half red, right half blue, big enough that the loupe crops from the middle.
    private func splitImage(width: Int = 100, height: Int = 100) -> CGImage {
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(NSColor.red.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
        ctx.setFillColor(NSColor.blue.cgColor)
        ctx.fill(CGRect(x: width / 2, y: 0, width: width - width / 2, height: height))
        return ctx.makeImage()!
    }

    private func rendered(_ view: LoupeView) -> NSBitmapImageRep {
        let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
        view.cacheDisplay(in: view.bounds, to: rep)
        return rep
    }

    private func color(_ rep: NSBitmapImageRep, _ view: NSView, x: CGFloat, y: CGFloat) -> NSColor {
        let k = CGFloat(rep.pixelsWide) / view.bounds.width
        return rep.colorAt(x: Int(x * k), y: Int(y * k))!.usingColorSpace(.sRGB)!
    }

    @Test func magnifiesThePixelsAroundTheCursor() {
        let view = LoupeView(frame: .zero)
        // Cursor on the red/blue boundary: the left of the box is red, the right is blue.
        view.show(source: splitImage(), pixel: (50, 50), label: "50, 50")
        let rep = rendered(view)
        let left = color(rep, view, x: 15, y: 75), right = color(rep, view, x: LoupeGeometry.boxSize - 15, y: 75)
        #expect(left.redComponent > 0.8 && left.blueComponent < 0.3)
        #expect(right.blueComponent > 0.8 && right.redComponent < 0.3)
    }

    @Test func nearAnEdgeTheCropShiftsButStillShowsImagePixels() {
        let view = LoupeView(frame: .zero)
        view.show(source: splitImage(), pixel: (0, 0), label: "0, 0")
        let rep = rendered(view)
        // The top-left of the image is red, so the whole box is red away from the crosshair.
        let c = color(rep, view, x: LoupeGeometry.boxSize - 15, y: LoupeGeometry.boxSize - 15)
        #expect(c.redComponent > 0.8 && c.blueComponent < 0.3)
    }

    @Test func sizeMatchesTheGeometryAndIgnoresTheMouse() {
        let view = LoupeView(frame: .zero)
        #expect(view.frame.size == LoupeView.fittingSize)
        #expect(view.hitTest(CGPoint(x: 10, y: 10)) == nil)
    }
}
