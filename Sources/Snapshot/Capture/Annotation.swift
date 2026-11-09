import Cocoa

enum Tool { case select, rect, arrow, pen, text }

struct Annotation {
    var tool: Tool
    var points: [CGPoint]
    var color: NSColor
    var text = ""
}

let annotationPalette: [NSColor] = [.systemRed, .systemOrange, .systemYellow, .systemGreen, .systemBlue, .white, .black]

extension Annotation {
    /// Draws the annotation into the current graphics context (view coordinates).
    func draw() {
        color.setStroke()
        color.setFill()
        guard let first = points.first, let last = points.last else { return }
        switch tool {
        case .rect:
            let p = NSBezierPath(rect: CGRect.spanning(first, last))
            p.lineWidth = 3
            p.stroke()
        case .arrow:
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
        case .pen:
            let p = NSBezierPath()
            p.lineWidth = 3
            p.lineCapStyle = .round
            p.lineJoinStyle = .round
            p.move(to: first)
            points.dropFirst().forEach { p.line(to: $0) }
            p.stroke()
        case .text:
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: 20), .foregroundColor: color,
            ]
            NSAttributedString(string: text, attributes: attrs).draw(at: first)
        case .select:
            break
        }
    }
}
