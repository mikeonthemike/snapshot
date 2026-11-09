import CoreGraphics

/// The caption shown above the selection: its size and where it is on the display.
enum SelectionReadout {
    /// "800 × 600 at 120, 340": size, then the top-left corner, in points from the display's top-left.
    static func text(for selection: CGRect) -> String {
        "\(Int(selection.width)) × \(Int(selection.height)) at \(Int(selection.minX)), \(Int(selection.minY))"
    }

    /// Where the caption's pill goes: just above the selection's top-left corner, below it if there's no room
    /// above, and never running off the right edge now that the caption is wider.
    static func pillFrame(textSize: CGSize, selection s: CGRect, bounds: CGRect) -> CGRect {
        let width = textSize.width + 12, height = textSize.height + 4
        let x = min(max(s.minX, bounds.minX + 4), bounds.maxX - width - 4)
        let y = max(s.minY - textSize.height - 10, 4)
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
