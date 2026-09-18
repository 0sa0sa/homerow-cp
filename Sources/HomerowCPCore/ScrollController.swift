public enum ScrollDirection {
    case up, down, left, right
}

public struct ScrollController {
    public init() {}

    public func direction(for key: Character) -> ScrollDirection? {
        switch key {
        case "k": return .up
        case "j": return .down
        case "h": return .left
        case "l": return .right
        default: return nil
        }
    }

    public func delta(for direction: ScrollDirection, step: Double = 40) -> (dx: Double, dy: Double) {
        switch direction {
        case .up: return (0, -step)
        case .down: return (0, step)
        case .left: return (-step, 0)
        case .right: return (step, 0)
        }
    }
}
