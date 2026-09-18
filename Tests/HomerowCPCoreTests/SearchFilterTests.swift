import XCTest
@testable import HomerowCPCore

final class SearchFilterTests: XCTestCase {
    let filter = SearchFilter()

    func test_emptyQueryMatchesEverything() {
        XCTAssertTrue(filter.matches(query: "", candidate: "Save Document"))
    }

    func test_matchesSubsequenceIgnoringCaseAndSpaces() {
        XCTAssertTrue(filter.matches(query: "svdoc", candidate: "Save Document"))
    }

    func test_doesNotMatchWhenCharsOutOfOrder() {
        XCTAssertFalse(filter.matches(query: "docsv", candidate: "Save Document"))
    }

    func test_filterReturnsOnlyMatchingElements() {
        let elements = [
            ClickableElement(stableID: "1", role: "AXButton", title: "Save Document", frame: ElementFrame(x: 0, y: 0, width: 1, height: 1)),
            ClickableElement(stableID: "2", role: "AXButton", title: "Cancel", frame: ElementFrame(x: 0, y: 0, width: 1, height: 1)),
        ]
        let result = filter.filter(query: "save", elements: elements)
        XCTAssertEqual(result.map(\.stableID), ["1"])
    }
}
