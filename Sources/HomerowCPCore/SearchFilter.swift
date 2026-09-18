public struct SearchFilter {
    public init() {}

    public func matches(query: String, candidate: String) -> Bool {
        guard !query.isEmpty else { return true }
        let normalizedQuery = query.lowercased().replacingOccurrences(of: " ", with: "")
        let normalizedCandidate = candidate.lowercased().replacingOccurrences(of: " ", with: "")

        var searchStart = normalizedCandidate.startIndex
        for qChar in normalizedQuery {
            guard searchStart < normalizedCandidate.endIndex,
                  let foundIndex = normalizedCandidate[searchStart...].firstIndex(of: qChar) else {
                return false
            }
            searchStart = normalizedCandidate.index(after: foundIndex)
        }
        return true
    }

    public func filter(query: String, elements: [ClickableElement]) -> [ClickableElement] {
        elements.filter { matches(query: query, candidate: $0.title ?? "") }
    }
}
