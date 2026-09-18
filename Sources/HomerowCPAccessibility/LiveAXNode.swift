import ApplicationServices
import HomerowCPCore

public final class LiveAXNode: AXNode {
    public let underlyingElement: AXUIElement
    private var element: AXUIElement { underlyingElement }

    public init(element: AXUIElement) {
        self.underlyingElement = element
    }

    public var role: String {
        var value: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &value)
        return value as? String ?? ""
    }

    public var title: String? {
        var value: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &value)
        return value as? String
    }

    public var isEnabled: Bool {
        var value: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXEnabledAttribute as CFString, &value)
        return (value as? Bool) ?? true
    }

    public var frame: ElementFrame? {
        var positionValue: AnyObject?
        var sizeValue: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionAXValue = positionValue, let sizeAXValue = sizeValue else {
            return nil
        }
        var point = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(positionAXValue as! AXValue, .cgPoint, &point)
        AXValueGetValue(sizeAXValue as! AXValue, .cgSize, &size)
        return ElementFrame(x: point.x, y: point.y, width: size.width, height: size.height)
    }

    public var children: [AXNode] {
        var value: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value)
        guard let axChildren = value as? [AXUIElement] else { return [] }
        return axChildren.map { LiveAXNode(element: $0) }
    }
}
