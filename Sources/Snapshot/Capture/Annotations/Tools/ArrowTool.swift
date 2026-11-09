import Cocoa

extension ToolSpec {
    static let arrow = ToolSpec(tool: .arrow, symbol: "arrow.up.right", title: "Arrow", interaction: .drag) { a, _ in
        guard let first = a.points.first, let last = a.points.last else { return }
        a.color.setStroke()
        a.color.setFill()
        let line = NSBezierPath()
        line.lineWidth = 3
        line.lineCapStyle = .round
        line.move(to: first)
        line.line(to: last)
        line.stroke()
        let angle = atan2(last.y - first.y, last.x - first.x)
        let len: CGFloat = 16
        let head = NSBezierPath()
        head.move(to: last)
        head.line(to: CGPoint(x: last.x - len * cos(angle - .pi / 7), y: last.y - len * sin(angle - .pi / 7)))
        head.line(to: CGPoint(x: last.x - len * cos(angle + .pi / 7), y: last.y - len * sin(angle + .pi / 7)))
        head.close()
        head.fill()
    }
}
