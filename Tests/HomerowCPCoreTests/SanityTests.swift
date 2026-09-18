import XCTest
@testable import HomerowCPCore

final class SanityTests: XCTestCase {
    func test_versionIsSet() {
        XCTAssertEqual(HomerowCPCore.version, "0.1.0")
    }
}
