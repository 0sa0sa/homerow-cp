import XCTest
@testable import HomerowCPCore

final class WindowCacheTests: XCTestCase {
    func test_updateThenReadReturnsElements() {
        let cache = WindowCache()
        let key = WindowKey(bundleID: "com.apple.finder", windowID: 1)
        let element = ClickableElement(stableID: "1", role: "AXButton", title: "Save", frame: ElementFrame(x: 0, y: 0, width: 1, height: 1))
        cache.update([element], for: key)
        XCTAssertEqual(cache.elements(for: key), [element])
    }

    func test_missingKeyReturnsNil() {
        let cache = WindowCache()
        let key = WindowKey(bundleID: "com.apple.finder", windowID: 99)
        XCTAssertNil(cache.elements(for: key))
    }

    func test_invalidateRemovesEntry() {
        let cache = WindowCache()
        let key = WindowKey(bundleID: "com.apple.finder", windowID: 1)
        cache.update([], for: key)
        cache.invalidate(key)
        XCTAssertNil(cache.elements(for: key))
    }
}
