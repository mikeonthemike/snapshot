import Cocoa

extension ToolSpec {
    static let pen = ToolSpec(tool: .pen, symbol: "pencil.tip", title: "Pen", interaction: .freehand) { a, _ in
        guard let first = a.points.first else { return }
        a.color.setStroke()
        let p = NSBezierPath()
        p.lineWidth = 3
        p.lineCapStyle = .round
        p.lineJoinStyle = .round
        p.move(to: first)
        a.points.dropFirst().forEach { p.line(to: $0) }
        p.stroke()
    }
}
