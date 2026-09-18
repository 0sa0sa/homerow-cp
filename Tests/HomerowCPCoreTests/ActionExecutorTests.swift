import XCTest
@testable import HomerowCPCore

final class ActionExecutorTests: XCTestCase {
    let executor = ActionExecutor()

    func test_leftAndCommandClickUsePressAction() {
        XCTAssertEqual(executor.chooseAXAction(for: .left), "AXPress")
        XCTAssertEqual(executor.chooseAXAction(for: .command), "AXPress")
    }

    func test_rightClickUsesShowMenuAction() {
        XCTAssertEqual(executor.chooseAXAction(for: .right), "AXShowMenu")
    }

    func test_centerPointComputesMidpointOfFrame() {
        let frame = ElementFrame(x: 10, y: 20, width: 100, height: 50)
        let center = executor.centerPoint(of: frame)
        XCTAssertEqual(center.x, 60)
        XCTAssertEqual(center.y, 45)
    }
}
