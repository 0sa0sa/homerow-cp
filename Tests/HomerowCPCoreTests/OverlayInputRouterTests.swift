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

    func test_engineOutputLabelsAreAllReachableViaRouter() {
        let engine = LabelAssignmentEngine()
        let elements = (0..<40).map { i in
            ClickableElement(stableID: "id-\(i)", role: "AXButton", title: nil, frame: ElementFrame(x: Double(i), y: 0, width: 10, height: 10))
        }
        let assignments = engine.assignLabels(elements: elements)
        let seamRouter = OverlayInputRouter()

        for assignment in assignments {
            var query = ""
            var lastResult: OverlayInputResult = .noMatch
            for char in assignment.label {
                lastResult = seamRouter.handle(character: char, currentQuery: query, assignments: assignments)
                if case .updatedQuery(let newQuery) = lastResult {
                    query = newQuery
                }
            }
            guard case .selected(let elementID) = lastResult else {
                XCTFail("Label '\(assignment.label)' is not reachable via the router (got \(lastResult))")
                continue
            }
            XCTAssertEqual(elementID, assignment.elementID, "Label '\(assignment.label)' selected the wrong element")
        }
    }
}
