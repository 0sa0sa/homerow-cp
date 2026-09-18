import XCTest
@testable import HomerowCPCore

final class LabelAssignmentEngineTests: XCTestCase {
    func makeElement(_ id: String) -> ClickableElement {
        ClickableElement(stableID: id, role: "AXButton", title: id, frame: ElementFrame(x: 0, y: 0, width: 10, height: 10))
    }

    func test_assignsSingleCharLabelsWhenFewerElementsThanHomeRowChars() {
        let engine = LabelAssignmentEngine()
        let elements = ["a", "b", "c"].map(makeElement)
        let result = engine.assignLabels(elements: elements)
        XCTAssertEqual(result.count, 3)
        XCTAssertTrue(result.allSatisfy { $0.label.count == 1 })
    }

    func test_higherFrequencyElementsGetShorterLabels() {
        let engine = LabelAssignmentEngine()
        let elements = (1...12).map { makeElement("el\($0)") }
        var scores: [String: Double] = [:]
        for i in 1...12 { scores["el\(i)"] = Double(12 - i) }
        let result = engine.assignLabels(elements: elements, frequencyScores: scores)
        let topElement = result.first { $0.elementID == "el1" }
        XCTAssertEqual(topElement?.label.count, 1)
        let lowestElement = result.first { $0.elementID == "el12" }
        XCTAssertEqual(lowestElement?.label.count, 2)
    }

    func test_preservesPreviousLabelWhenStillAvailable() {
        let engine = LabelAssignmentEngine()
        let elements = ["a", "b", "c"].map(makeElement)
        let first = engine.assignLabels(elements: elements)
        let previous = Dictionary(uniqueKeysWithValues: first.map { ($0.elementID, $0.label) })
        let second = engine.assignLabels(elements: elements, previousAssignments: previous)
        XCTAssertEqual(Set(first), Set(second))
    }

    func test_overflowUsesTwoCharLabelsWhenMoreThanNineElements() {
        let engine = LabelAssignmentEngine()
        let elements = (1...15).map { makeElement("el\($0)") }
        let result = engine.assignLabels(elements: elements)
        let twoCharCount = result.filter { $0.label.count == 2 }.count
        XCTAssertEqual(twoCharCount, 15 - LabelAssignmentEngine.homeRowChars.count)
    }
}
