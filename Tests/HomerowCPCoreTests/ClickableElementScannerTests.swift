import XCTest
@testable import HomerowCPCore

final class FakeAXNode: AXNode {
    let role: String
    let title: String?
    let frame: ElementFrame?
    let isEnabled: Bool
    var children: [AXNode]

    init(role: String, title: String? = nil, frame: ElementFrame? = ElementFrame(x: 0, y: 0, width: 10, height: 10), isEnabled: Bool = true, children: [AXNode] = []) {
        self.role = role
        self.title = title
        self.frame = frame
        self.isEnabled = isEnabled
        self.children = children
    }
}

final class ClickableElementScannerTests: XCTestCase {
    func test_findsClickableElementsAndSkipsNonClickableRoles() {
        let root = FakeAXNode(role: "AXWindow", frame: nil, children: [
            FakeAXNode(role: "AXButton", title: "Save"),
            FakeAXNode(role: "AXGroup", frame: nil, children: [
                FakeAXNode(role: "AXLink", title: "Learn More"),
            ]),
        ])
        let scanner = ClickableElementScanner(bundleID: "com.example.app", windowRole: "AXWindow")
        let result = scanner.scan(root: root)
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.contains { $0.title == "Save" })
        XCTAssertTrue(result.contains { $0.title == "Learn More" })
    }

    func test_skipsDisabledElements() {
        let root = FakeAXNode(role: "AXWindow", frame: nil, children: [
            FakeAXNode(role: "AXButton", title: "Disabled", isEnabled: false),
        ])
        let scanner = ClickableElementScanner(bundleID: "com.example.app", windowRole: "AXWindow")
        let result = scanner.scan(root: root)
        XCTAssertTrue(result.isEmpty)
    }

    func test_skipsElementsWithoutFrame() {
        let root = FakeAXNode(role: "AXWindow", frame: nil, children: [
            FakeAXNode(role: "AXButton", title: "NoFrame", frame: nil),
        ])
        let scanner = ClickableElementScanner(bundleID: "com.example.app", windowRole: "AXWindow")
        let result = scanner.scan(root: root)
        XCTAssertTrue(result.isEmpty)
    }

    func test_scanPairedReturnsMatchingSourceNode() {
        let button = FakeAXNode(role: "AXButton", title: "Save")
        let root = FakeAXNode(role: "AXWindow", frame: nil, children: [button])
        let scanner = ClickableElementScanner(bundleID: "com.example.app", windowRole: "AXWindow")
        let pairs = scanner.scanPaired(root: root)
        XCTAssertEqual(pairs.count, 1)
        XCTAssertTrue(pairs[0].node as? FakeAXNode === button)
    }
}
