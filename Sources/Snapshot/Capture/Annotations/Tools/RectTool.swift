import Cocoa

extension ToolSpec {
    static let rect = ToolSpec(tool: .rect, symbol: "rectangle", title: "Rectangle", interaction: .drag) { a, _ in
        guard let first = a.points.first, let last = a.points.last else { return }
        a.color.setStroke()
        let p = NSBezierPath(rect: CGRect.spanning(first, last))
        p.lineWidth = 3
        p.stroke()
    }
}
