public protocol AXNode {
    var role: String { get }
    var title: String? { get }
    var frame: ElementFrame? { get }
    var isEnabled: Bool { get }
    var children: [AXNode] { get }
}
