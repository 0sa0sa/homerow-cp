public enum ClickKind {
    case left, right, double, command
}

public struct ActionExecutor {
    public init() {}

    public func chooseAXAction(for kind: ClickKind) -> String {
        switch kind {
        case .left, .command, .double:
            return "AXPress"
        case .right:
            return "AXShowMenu"
        }
    }

    public func centerPoint(of frame: ElementFrame) -> (x: Double, y: Double) {
        (x: frame.x + frame.width / 2, y: frame.y + frame.height / 2)
    }
}
