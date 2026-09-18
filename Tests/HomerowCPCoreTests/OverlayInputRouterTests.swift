import XCTest
@testable import HomerowCPCore

final class OverlayInputRouterTests: XCTestCase {
    let router = OverlayInputRouter()
    let assignments = [
        LabelAssignment(elementID: "1", label: "a"),
        LabelAssignment(elementID: "2", label: "sd"),
        LabelAssignment(elementID: "3", label: "sf"),
    ]

    func test_exactSingleCharMatchSelectsImmediately() {
        let result = router.handle(character: "a", currentQuery: "", assignments: assignments)
        XCTAssertEqual(result, .selected(elementID: "1"))
    }

    func test_prefixOfTwoCharLabelUpdatesQuery() {
        let result = router.handle(character: "s", currentQuery: "", assignments: assignments)
        XCTAssertEqual(result, .updatedQuery("s"))
    }

    func test_secondCharacterCompletesTwoCharLabel() {
        let result = router.handle(character: "d", currentQuery: "s", assignments: assignments)
        XCTAssertEqual(result, .selected(elementID: "2"))
    }

    func test_unmatchableCharacterReturnsNoMatch() {
        let result = router.handle(character: "z", currentQuery: "", assignments: assignments)
        XCTAssertEqual(result, .noMatch)
    }

    func test_escapeDismisses() {
        let result = router.handle(character: "\u{1B}", currentQuery: "s", assignments: assignments)
        XCTAssertEqual(result, .dismiss)
    }
}
