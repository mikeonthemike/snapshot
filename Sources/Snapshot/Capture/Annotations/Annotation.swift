import Cocoa

/// Which tool is active. `.select` means no drawing tool (the selection can be moved and resized).
enum Tool: Hashable { case select, rect, arrow, pen, highlighter, pixelate, step, text }

struct Annotation {
    var tool: Tool
    var points: [CGPoint]
    var color: NSColor
    var text = ""
    /// For numbered step markers.
    var number = 0
}

let annotationPalette: [NSColor] = [.systemRed, .systemOrange, .systemYellow, .systemGreen, .systemBlue, .white, .black]

extension Annotation {
    /// Draws the annotation into the current graphics context (view coordinates).
    func draw(in context: AnnotationContext) {
        AnnotationTools.spec(for: tool)?.draw(self, context)
    }

    /// The number the next step marker should get.
    static func nextStepNumber(in annotations: [Annotation]) -> Int {
        annotations.filter { $0.tool == .step }.count + 1
    }
}
