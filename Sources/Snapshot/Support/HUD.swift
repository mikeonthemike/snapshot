import Cocoa

/// Wraps a stack of buttons in the blurred, rounded HUD container shared by the capture toolbar and the
/// recording bar. The returned view is already sized to fit the stack.
func makeHUDContainer(around stack: NSStackView, cornerRadius: CGFloat, appearance: NSAppearance? = nil) -> NSVisualEffectView {
    let fx = NSVisualEffectView()
    fx.material = .hudWindow
    fx.state = .active
    if let appearance = appearance { fx.appearance = appearance }
    fx.wantsLayer = true
    fx.layer?.cornerRadius = cornerRadius
    fx.layer?.masksToBounds = true
    stack.translatesAutoresizingMaskIntoConstraints = false
    fx.addSubview(stack)
    NSLayoutConstraint.activate([
        stack.leadingAnchor.constraint(equalTo: fx.leadingAnchor), stack.trailingAnchor.constraint(equalTo: fx.trailingAnchor),
        stack.topAnchor.constraint(equalTo: fx.topAnchor), stack.bottomAnchor.constraint(equalTo: fx.bottomAnchor),
    ])
    fx.frame = CGRect(origin: .zero, size: stack.fittingSize)
    return fx
}
