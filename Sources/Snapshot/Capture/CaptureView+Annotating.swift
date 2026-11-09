import Cocoa

// Starting annotations from a mouse press, driven by each tool's `ToolSpec`.
extension CaptureView {
    var annotationContext: AnnotationContext {
        AnnotationContext(source: sourceImage, bounds: bounds)
    }

    /// Called when the mouse goes down inside the selection with a drawing tool active.
    func beginAnnotation(at p: CGPoint) {
        guard let spec = AnnotationTools.spec(for: tool) else { return }
        switch spec.interaction {
        case .text:
            beginText(at: p)
        case .click:
            annotations.append(Annotation(tool: tool, points: [p], color: color,
                                          number: Annotation.nextStepNumber(in: annotations)))
        case .drag, .freehand:
            current = Annotation(tool: tool, points: [p], color: color)
        }
    }
}
