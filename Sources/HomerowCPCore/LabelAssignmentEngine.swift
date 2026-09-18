public struct LabelAssignment: Equatable, Hashable {
    public let elementID: String
    public let label: String

    public init(elementID: String, label: String) {
        self.elementID = elementID
        self.label = label
    }
}

public struct LabelAssignmentEngine {
    public static let homeRowChars: [Character] = Array("asdfghjkl")

    public init() {}

    public func assignLabels(
        elements: [ClickableElement],
        frequencyScores: [String: Double] = [:],
        previousAssignments: [String: String] = [:]
    ) -> [LabelAssignment] {
        let sortedElements = elements.sorted { lhs, rhs in
            let l = frequencyScores[lhs.stableID] ?? 0
            let r = frequencyScores[rhs.stableID] ?? 0
            if l != r { return l > r }
            return lhs.stableID < rhs.stableID
        }

        var pool = generateLabelPool(count: sortedElements.count)
        var assignedElementIDs = Set<String>()
        var result: [LabelAssignment] = []

        for element in sortedElements {
            guard let prev = previousAssignments[element.stableID],
                  let index = pool.firstIndex(of: prev) else { continue }
            pool.remove(at: index)
            assignedElementIDs.insert(element.stableID)
            result.append(LabelAssignment(elementID: element.stableID, label: prev))
        }

        for element in sortedElements {
            guard !assignedElementIDs.contains(element.stableID) else { continue }
            guard !pool.isEmpty else { break }
            let label = pool.removeFirst()
            assignedElementIDs.insert(element.stableID)
            result.append(LabelAssignment(elementID: element.stableID, label: label))
        }

        return result
    }

    private func generateLabelPool(count: Int) -> [String] {
        let chars = Self.homeRowChars
        let m = chars.count
        guard count > m else {
            return chars.map { String($0) }
        }

        let rawSingleCount = (m * m - count) / (m - 1)
        let singleCount = max(0, min(m, rawSingleCount))

        var pool: [String] = chars.prefix(singleCount).map { String($0) }
        let prefixChars = chars.suffix(m - singleCount)
        outer: for c1 in prefixChars {
            for c2 in chars {
                pool.append("\(c1)\(c2)")
                if pool.count >= count { break outer }
            }
        }
        return pool
    }
}
