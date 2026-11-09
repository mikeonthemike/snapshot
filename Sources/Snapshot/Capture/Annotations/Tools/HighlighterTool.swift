import Cocoa

extension ToolSpec {
    /// A wide, translucent freehand stroke, like a marker pen.
    static let highlighter = ToolSpec(tool: .highlighter, symbol: "highlighter", title: "Highlighter", interaction: .freehand) { a, _ in
        guard let first = a.points.first else { return }
        a.color.withAlphaComponent(0.4).setStroke()
        let p = NSBezierPath()
        p.lineWidth = 18
        p.lineCapStyle = .round
        p.lineJoinStyle = .round
        p.move(to: first)
        a.points.dropFirst().forEach { p.line(to: $0) }
        // A lone click still leaves a dot.
        if a.points.count == 1 { p.line(to: first) }
        p.stroke()
    }
}
