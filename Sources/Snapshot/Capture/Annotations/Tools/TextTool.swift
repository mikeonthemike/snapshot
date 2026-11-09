import Cocoa

extension ToolSpec {
    static let text = ToolSpec(tool: .text, symbol: "textformat", title: "Text", interaction: .text) { a, _ in
        guard let first = a.points.first else { return }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 20), .foregroundColor: a.color,
        ]
        NSAttributedString(string: a.text, attributes: attrs).draw(at: first)
    }
}
