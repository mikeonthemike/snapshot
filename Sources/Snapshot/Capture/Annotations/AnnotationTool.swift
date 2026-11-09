import Cocoa

/// What an annotation needs besides its own data when it draws.
struct AnnotationContext {
    /// The full, unannotated screenshot. Tools like pixelate sample it.
    let source: CGImage?
    /// The view bounds the screenshot is drawn into.
    let bounds: CGRect
}

/// Everything the capture view needs to know about a drawing tool. Adding a tool is one new
/// `ToolSpec` in `Tools/`, a `Tool` case, and one line in `AnnotationTools.all`.
struct ToolSpec {
    /// How the user creates the annotation with the mouse.
    enum Interaction {
        /// Press, drag, release: the annotation spans start and current point (rectangle, arrow).
        case drag
        /// Press and drag: every point along the path is kept (pen, highlighter).
        case freehand
        /// A single click places it (step markers).
        case click
        /// A click opens an inline text field.
        case text
    }

    let tool: Tool
    let symbol: String
    let title: String
    let interaction: Interaction
    let draw: (Annotation, AnnotationContext) -> Void
}

enum AnnotationTools {
    /// In toolbar order.
    static let all: [ToolSpec] = [.rect, .arrow, .pen, .highlighter, .pixelate, .step, .text]

    static func spec(for tool: Tool) -> ToolSpec? {
        all.first { $0.tool == tool }
    }
}
