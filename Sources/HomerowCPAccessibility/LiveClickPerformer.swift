import ApplicationServices
import HomerowCPCore

public struct LiveClickPerformer {
    private let executor = ActionExecutor()

    public init() {}

    public func perform(kind: ClickKind, on element: AXUIElement, frame: ElementFrame) {
        let actionName = executor.chooseAXAction(for: kind)
        let result = AXUIElementPerformAction(element, actionName as CFString)

        if result != .success, kind != .right {
            // AXPressに応じないカスタム描画要素向けのフォールバック: 中心点へ合成マウスクリックを送る
            let center = executor.centerPoint(of: frame)
            postSyntheticClick(at: CGPoint(x: center.x, y: center.y), doubleClick: kind == .double, commandModifier: kind == .command)
        } else if result == .success, kind == .double {
            _ = AXUIElementPerformAction(element, actionName as CFString)
        }
    }

    private func postSyntheticClick(at point: CGPoint, doubleClick: Bool, commandModifier: Bool) {
        let flags: CGEventFlags = commandModifier ? .maskCommand : []
        let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
        let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
        down?.flags = flags
        up?.flags = flags
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
        if doubleClick {
            down?.post(tap: .cghidEventTap)
            up?.post(tap: .cghidEventTap)
        }
    }
}
