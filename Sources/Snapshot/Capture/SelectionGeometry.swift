import Cocoa

/// One of the eight drag handles around a selection.
enum SelectionHandle: CaseIterable {
    case topLeft, top, topRight, left, right, bottomLeft, bottom, bottomRight

    /// Position along each axis (0 = min edge, 0.5 = middle, 1 = max edge) in the view's flipped coordinates.
    var factors: (CGFloat, CGFloat) {
        switch self {
        case .topLeft: return (0, 0)
        case .top: return (0.5, 0)
        case .topRight: return (1, 0)
        case .left: return (0, 0.5)
        case .right: return (1, 0.5)
        case .bottomLeft: return (0, 1)
        case .bottom: return (0.5, 1)
        case .bottomRight: return (1, 1)
        }
    }

    var cursor: NSCursor {
        if #available(macOS 15.0, *) {
            let pos: NSCursor.FrameResizePosition
            switch self {
            case .topLeft: pos = .topLeft
            case .top: pos = .top
            case .topRight: pos = .topRight
            case .left: pos = .left
            case .right: pos = .right
            case .bottomLeft: pos = .bottomLeft
            case .bottom: pos = .bottom
            case .bottomRight: pos = .bottomRight
            }
            return NSCursor.frameResize(position: pos, directions: .all)
        }
        switch self {
        case .top, .bottom: return .resizeUpDown
        default: return .resizeLeftRight
        }
    }
}

extension CGRect {
    /// The rectangle with the two points as opposite corners, whichever way round they are.
    static func spanning(_ a: CGPoint, _ b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }
}

/// Pure geometry for the capture selection: handle hit-testing, resizing, moving and toolbar placement.
/// No views or state, so it can be unit tested. All coordinates are in the capture view's flipped space.
enum SelectionGeometry {
    static let handleSize: CGFloat = 10
    /// Extra grab area around each handle when hit-testing.
    static let handleHitSlop: CGFloat = 3

    static func handleRect(_ h: SelectionHandle, in selection: CGRect) -> CGRect {
        let (fx, fy) = h.factors
        let half = handleSize / 2
        return CGRect(x: selection.minX + selection.width * fx - half, y: selection.minY + selection.height * fy - half,
                      width: handleSize, height: handleSize)
    }

    static func handle(at p: CGPoint, in selection: CGRect) -> SelectionHandle? {
        SelectionHandle.allCases.first {
            handleRect($0, in: selection).insetBy(dx: -handleHitSlop, dy: -handleHitSlop).contains(p)
        }
    }

    /// The selection after dragging `handle` to `p`, clamped to `bounds`.
    static func resized(_ original: CGRect, dragging handle: SelectionHandle, to p: CGPoint, within bounds: CGRect) -> CGRect {
        let (fx, fy) = handle.factors
        var x0 = original.minX, x1 = original.maxX, y0 = original.minY, y1 = original.maxY
        if fx == 0 { x0 = p.x } else if fx == 1 { x1 = p.x }
        if fy == 0 { y0 = p.y } else if fy == 1 { y1 = p.y }
        return CGRect.spanning(CGPoint(x: x0, y: y0), CGPoint(x: x1, y: y1)).intersection(bounds)
    }

    /// The selection moved by `delta`, kept entirely inside `bounds`.
    static func moved(_ original: CGRect, by delta: CGPoint, within bounds: CGRect) -> CGRect {
        let dx = min(max(delta.x, -original.minX), bounds.maxX - original.maxX)
        let dy = min(max(delta.y, -original.minY), bounds.maxY - original.maxY)
        return original.offsetBy(dx: dx, dy: dy)
    }

    /// Where to put the toolbar: under the selection's right edge, falling back to above or inside it.
    static func toolbarOrigin(size: CGSize, selection s: CGRect, bounds: CGRect) -> CGPoint {
        var origin = CGPoint(x: s.maxX - size.width, y: s.maxY + 8)
        if origin.y + size.height > bounds.maxY - 4 { origin.y = s.minY - size.height - 30 }
        if origin.y < 4 { origin.y = s.maxY - size.height - 8 }
        origin.x = min(max(origin.x, 8), bounds.maxX - size.width - 8)
        return origin
    }
}

/// The arrow keys, as used to nudge the selection.
enum ArrowKey: CaseIterable {
    case left, right, up, down

    init?(keyCode: UInt16) {
        switch keyCode {
        case 123: self = .left
        case 124: self = .right
        case 125: self = .down
        case 126: self = .up
        default: return nil
        }
    }

    /// Unit step in the capture view's flipped space (y grows downward).
    var vector: CGPoint {
        switch self {
        case .left: return CGPoint(x: -1, y: 0)
        case .right: return CGPoint(x: 1, y: 0)
        case .up: return CGPoint(x: 0, y: -1)
        case .down: return CGPoint(x: 0, y: 1)
        }
    }
}

extension SelectionGeometry {
    /// Smallest selection the keyboard can shrink to, matching the minimum for mouse resizing.
    static let minimumSize: CGFloat = 8

    /// The selection with its width and height changed by `dw` and `dh`, top-left fixed, kept between
    /// `minimumSize` and the edge of `bounds`.
    static func resized(_ s: CGRect, byWidth dw: CGFloat, height dh: CGFloat, within bounds: CGRect) -> CGRect {
        let w = min(max(s.width + dw, minimumSize), bounds.maxX - s.minX)
        let h = min(max(s.height + dh, minimumSize), bounds.maxY - s.minY)
        return CGRect(x: s.minX, y: s.minY, width: w, height: h)
    }
}
