import XCTest
@testable import HomerowCPCore

final class StableIDGeneratorTests: XCTestCase {
    func test_sameInputsProduceSameID() {
        let id1 = StableIDGenerator.makeID(
            bundleID: "com.apple.finder", windowRole: "AXWindow",
            elementRole: "AXButton", title: "Save",
            approximatePosition: (row: 2, col: 3)
        )
        let id2 = StableIDGenerator.makeID(
            bundleID: "com.apple.finder", windowRole: "AXWindow",
            elementRole: "AXButton", title: "Save",
            approximatePosition: (row: 2, col: 3)
        )
        XCTAssertEqual(id1, id2)
    }

    func test_differentTitlesProduceDifferentIDs() {
        let id1 = StableIDGenerator.makeID(
            bundleID: "com.apple.finder", windowRole: "AXWindow",
            elementRole: "AXButton", title: "Save",
            approximatePosition: (row: 2, col: 3)
        )
        let id2 = StableIDGenerator.makeID(
            bundleID: "com.apple.finder", windowRole: "AXWindow",
            elementRole: "AXButton", title: "Cancel",
            approximatePosition: (row: 2, col: 3)
        )
        XCTAssertNotEqual(id1, id2)
    }

    func test_bucketedPositionRoundsNearbyPointsToSameBucket() {
        let a = bucketedPosition(x: 101, y: 202)
        let b = bucketedPosition(x: 110, y: 210)
        XCTAssertEqual(a.row, b.row)
        XCTAssertEqual(a.col, b.col)
    }

    func test_nilTitleProducesValidID() {
        let id = StableIDGenerator.makeID(
            bundleID: "com.apple.finder", windowRole: "AXWindow",
            elementRole: "AXButton", title: nil,
            approximatePosition: (row: 1, col: 1)
        )
        XCTAssertFalse(id.isEmpty)
    }

    func test_differentPositionsProduceDifferentIDs() {
        let id1 = StableIDGenerator.makeID(
            bundleID: "com.apple.finder", windowRole: "AXWindow",
            elementRole: "AXButton", title: "Save",
            approximatePosition: (row: 1, col: 1)
        )
        let id2 = StableIDGenerator.makeID(
            bundleID: "com.apple.finder", windowRole: "AXWindow",
            elementRole: "AXButton", title: "Save",
            approximatePosition: (row: 2, col: 5)
        )
        XCTAssertNotEqual(id1, id2)
    }
}
