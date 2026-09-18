public enum OverlayInputResult: Equatable {
    case selected(elementID: String)
    case updatedQuery(String)
    case noMatch
    case dismiss
}

public struct OverlayInputRouter {
    public init() {}

    public func handle(character: Character, currentQuery: String, assignments: [LabelAssignment]) -> OverlayInputResult {
        if character == "\u{1B}" {
            return .dismiss
        }

        let newQuery = currentQuery + String(character)

        if let exact = assignments.first(where: { $0.label == newQuery }) {
            return .selected(elementID: exact.elementID)
        }

        let stillPossible = assignments.contains { $0.label.hasPrefix(newQuery) }
        if stillPossible {
            return .updatedQuery(newQuery)
        }

        return .noMatch
    }
}
