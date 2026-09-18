import XCTest
@testable import HomerowCPCore

final class ScrollControllerTests: XCTestCase {
    let controller = ScrollController()

    func test_hjklMapToDirections() {
        XCTAssertEqual(controller.direction(for: "k"), .up)
        XCTAssertEqual(controller.direction(for: "j"), .down)
        XCTAssertEqual(controller.direction(for: "h"), .left)
        XCTAssertEqual(controller.direction(for: "l"), .right)
    }

    func test_unknownKeyReturnsNil() {
        XCTAssertNil(controller.direction(for: "x"))
    }

    func test_deltaForUpIsNegativeY() {
        let delta = controller.delta(for: .up, step: 40)
        XCTAssertEqual(delta.dx, 0)
        XCTAssertEqual(delta.dy, -40)
    }

    func test_deltaForRightIsPositiveX() {
        let delta = controller.delta(for: .right, step: 40)
        XCTAssertEqual(delta.dx, 40)
        XCTAssertEqual(delta.dy, 0)
    }
}
