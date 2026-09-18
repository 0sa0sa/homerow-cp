public struct ElementFrame: Equatable, Codable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct ClickableElement: Equatable {
    public let stableID: String
    public let role: String
    public let title: String?
    public let frame: ElementFrame

    public init(stableID: String, role: String, title: String?, frame: ElementFrame) {
        self.stableID = stableID
        self.role = role
        self.title = title
        self.frame = frame
    }
}
