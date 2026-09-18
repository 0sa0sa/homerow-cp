import XCTest
@testable import HomerowCPCore

final class KeyComboParserTests: XCTestCase {
    func test_parsesCmdShiftSpace() {
        let combo = KeyComboParser.parse("cmd+shift+space")
        XCTAssertNotNil(combo)
        XCTAssertEqual(combo?.keyCode, 49)
    }

    func test_returnsNilForUnknownKey() {
        XCTAssertNil(KeyComboParser.parse("cmd+unknownkey"))
    }

    func test_returnsNilForUnknownModifier() {
        XCTAssertNil(KeyComboParser.parse("meta+space"))
    }

    func test_singleKeyWithNoModifierParses() {
        let combo = KeyComboParser.parse("space")
        XCTAssertEqual(combo?.modifiers, 0)
    }
}
