public struct ClickableElementScanner {
    public static let defaultClickableRoles: Set<String> = [
        "AXButton", "AXCheckBox", "AXRadioButton", "AXPopUpButton",
        "AXMenuButton", "AXLink", "AXTextField", "AXComboBox",
        "AXDisclosureTriangle", "AXTab", "AXMenuItem",
    ]

    private let bundleID: String
    private let windowRole: String
    private let clickableRoles: Set<String>

    public init(bundleID: String, windowRole: String, clickableRoles: Set<String> = ClickableElementScanner.defaultClickableRoles) {
        self.bundleID = bundleID
        self.windowRole = windowRole
        self.clickableRoles = clickableRoles
    }

    public func scan(root: AXNode, maxDepth: Int = 50) -> [ClickableElement] {
        scanPaired(root: root, maxDepth: maxDepth).map(\.element)
    }

    /// Same traversal as `scan`, but also returns the source `AXNode` for each result.
    /// `AccessibilityIndexer` uses the paired node (downcast to `LiveAXNode`) to recover
    /// the underlying `AXUIElement` needed to actually perform a click.
    public func scanPaired(root: AXNode, maxDepth: Int = 50) -> [(element: ClickableElement, node: AXNode)] {
        var results: [(element: ClickableElement, node: AXNode)] = []
        walk(node: root, depth: 0, maxDepth: maxDepth, into: &results)
        return results
    }

    private func walk(node: AXNode, depth: Int, maxDepth: Int, into results: inout [(element: ClickableElement, node: AXNode)]) {
        guard depth <= maxDepth else { return }

        if clickableRoles.contains(node.role), node.isEnabled, let frame = node.frame {
            let bucketed = bucketedPosition(x: frame.x, y: frame.y)
            let id = StableIDGenerator.makeID(
                bundleID: bundleID,
                windowRole: windowRole,
                elementRole: node.role,
                title: node.title,
                approximatePosition: bucketed
            )
            let clickable = ClickableElement(stableID: id, role: node.role, title: node.title, frame: frame)
            results.append((element: clickable, node: node))
        }

        for child in node.children {
            walk(node: child, depth: depth + 1, maxDepth: maxDepth, into: &results)
        }
    }
}
