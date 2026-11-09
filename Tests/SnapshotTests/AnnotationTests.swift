import Testing
import Cocoa
@testable import Snapshot

/// Renders into a top-left-origin bitmap the same way `CaptureView.render()` does.
private func render(size: CGSize, background: NSColor = .white, _ body: () -> Void) -> NSBitmapImageRep {
    let w = Int(size.width), h = Int(size.height)
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setFillColor(background.cgColor)
    ctx.fill(CGRect(origin: .zero, size: size))
    ctx.translateBy(x: 0, y: CGFloat(h))
    ctx.scaleBy(x: 1, y: -1)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
    body()
    NSGraphicsContext.restoreGraphicsState()
    return NSBitmapImageRep(cgImage: ctx.makeImage()!)
}

private func rgb(_ rep: NSBitmapImageRep, _ x: Int, _ y: Int) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
    let c = rep.colorAt(x: x, y: y)!.usingColorSpace(.sRGB)!
    return (c.redComponent, c.greenComponent, c.blueComponent)
}

private func isWhite(_ c: (r: CGFloat, g: CGFloat, b: CGFloat)) -> Bool {
    c.r > 0.99 && c.g > 0.99 && c.b > 0.99
}

/// Left half red, right half blue.
private func splitImage(size: Int = 100) -> CGImage {
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setFillColor(NSColor.red.cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: size / 2, height: size))
    ctx.setFillColor(NSColor.blue.cgColor)
    ctx.fill(CGRect(x: size / 2, y: 0, width: size / 2, height: size))
    return ctx.makeImage()!
}

@Suite struct ToolRegistryTests {
    @Test func everyDrawingToolHasExactlyOneSpec() {
        let tools = AnnotationTools.all.map(\.tool)
        #expect(Set(tools).count == tools.count)
        #expect(!tools.contains(.select))
        for tool in [Tool.rect, .arrow, .pen, .highlighter, .pixelate, .step, .text] {
            #expect(AnnotationTools.spec(for: tool) != nil)
        }
        #expect(AnnotationTools.spec(for: .select) == nil)
    }

    @Test func everySymbolExistsOnThisSystem() {
        for spec in AnnotationTools.all {
            #expect(NSImage(systemSymbolName: spec.symbol, accessibilityDescription: nil) != nil, "missing symbol \(spec.symbol)")
        }
    }

    @Test func stepNumbersCountExistingStepsOnly() {
        let step = Annotation(tool: .step, points: [.zero], color: .red, number: 1)
        let rect = Annotation(tool: .rect, points: [.zero, .zero], color: .red)
        #expect(Annotation.nextStepNumber(in: []) == 1)
        #expect(Annotation.nextStepNumber(in: [step, rect]) == 2)
        #expect(Annotation.nextStepNumber(in: [step, step, step]) == 4)
    }

    @Test func readableForegroundPicksContrast() {
        #expect(NSColor.black.readableForegroundColor == .white)
        #expect(NSColor.white.readableForegroundColor == .black)
        #expect(NSColor.systemYellow.readableForegroundColor == .black)
    }
}

@Suite struct PixelatorTests {
    @Test func outputMatchesTheRectSize() throws {
        let out = try #require(Pixelator.pixelated(splitImage(), rect: CGRect(x: 10, y: 20, width: 40, height: 30), blockSize: 8))
        #expect(out.width == 40 && out.height == 30)
    }

    @Test func rectIsClampedToTheImage() throws {
        let out = try #require(Pixelator.pixelated(splitImage(), rect: CGRect(x: 80, y: 80, width: 100, height: 100), blockSize: 8))
        #expect(out.width == 20 && out.height == 20)
    }

    @Test func emptyOrOutsideRectGivesNil() {
        #expect(Pixelator.pixelated(splitImage(), rect: CGRect(x: 500, y: 500, width: 10, height: 10), blockSize: 8) == nil)
        #expect(Pixelator.pixelated(splitImage(), rect: .zero, blockSize: 8) == nil)
    }

    @Test func oneBlockCoveringEverythingIsAUniformAverage() throws {
        let out = try #require(Pixelator.pixelated(splitImage(), rect: CGRect(x: 0, y: 0, width: 100, height: 100), blockSize: 100))
        let rep = NSBitmapImageRep(cgImage: out)
        let a = rgb(rep, 5, 5), b = rgb(rep, 95, 95)
        #expect(a == b)
        #expect(a.r > 0.2 && a.b > 0.2)   // a mix of the red and blue halves
    }

    @Test func smallBlocksHideDetailButStayBlockwiseUniform() throws {
        let out = try #require(Pixelator.pixelated(splitImage(), rect: CGRect(x: 0, y: 0, width: 100, height: 100), blockSize: 20))
        let rep = NSBitmapImageRep(cgImage: out)
        // Pixels inside the same 20px block are identical.
        #expect(rgb(rep, 1, 1) == rgb(rep, 18, 18))
        // Blocks on opposite sides of the split differ.
        #expect(rgb(rep, 5, 50) != rgb(rep, 95, 50))
    }
}

@Suite struct ToolDrawingTests {
    private let size = CGSize(width: 120, height: 120)

    private func draw(_ a: Annotation, source: CGImage? = nil) -> NSBitmapImageRep {
        render(size: size) {
            a.draw(in: AnnotationContext(source: source, bounds: CGRect(origin: .zero, size: size)))
        }
    }

    @Test func rectangleDrawsItsOutlineNotItsFill() {
        let rep = draw(Annotation(tool: .rect, points: [CGPoint(x: 20, y: 20), CGPoint(x: 100, y: 100)], color: .red))
        #expect(rgb(rep, 20, 60).g < 0.3)     // on the left edge
        #expect(isWhite(rgb(rep, 60, 60))) // interior untouched
    }

    @Test func stepMarkerFillsItsCircle() {
        let rep = draw(Annotation(tool: .step, points: [CGPoint(x: 60, y: 60)], color: .blue, number: 3))
        // Near the edge of the circle (away from the digit) the colour is solid blue.
        let edge = rgb(rep, 60 + 9, 60)
        #expect(edge.b > 0.8 && edge.r < 0.3)
        #expect(isWhite(rgb(rep, 5, 5)))
    }

    @Test func highlighterIsTranslucent() {
        let rep = draw(Annotation(tool: .highlighter, points: [CGPoint(x: 10, y: 60), CGPoint(x: 110, y: 60)], color: .black))
        let c = rgb(rep, 60, 60)
        #expect(c.r > 0.4 && c.r < 0.8)   // grey: black at ~40% over white
    }

    @Test func pixelateReplacesTheAreaWithTheAveragedSource() {
        let src = splitImage(size: 120)
        let a = Annotation(tool: .pixelate, points: [CGPoint(x: 0, y: 0), CGPoint(x: 120, y: 120)], color: .red)
        // Block size is 10 pt; the whole image is drawn at scale 1, so blocks are 10px. A block straddling the
        // red/blue boundary (x 60) doesn't exist, so edges stay pure; check the left is red, the right is blue.
        let rep = draw(a, source: src)
        #expect(rgb(rep, 5, 60).r > 0.8)
        #expect(rgb(rep, 115, 60).b > 0.8)
    }

    @Test func pixelateWithoutASourceFallsBackToASolidFill() {
        let a = Annotation(tool: .pixelate, points: [CGPoint(x: 20, y: 20), CGPoint(x: 100, y: 100)], color: .red)
        let rep = draw(a, source: nil)
        #expect(!isWhite(rgb(rep, 60, 60)))
    }
}
