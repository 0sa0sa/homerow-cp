import XCTest
@testable import HomerowCPCore

final class FrequencyTrackerTests: XCTestCase {
    func tempStoreURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("freq-\(UUID().uuidString).json")
    }

    func test_recordSelectionIncrementsScore() {
        let tracker = FrequencyTracker(storeURL: tempStoreURL())
        XCTAssertEqual(tracker.score(for: "el1"), 0)
        tracker.recordSelection(elementID: "el1")
        XCTAssertEqual(tracker.score(for: "el1"), 1)
        tracker.recordSelection(elementID: "el1")
        XCTAssertEqual(tracker.score(for: "el1"), 2)
    }

    func test_decayReducesScoreOverTime() {
        let tracker = FrequencyTracker(storeURL: tempStoreURL(), decayFactor: 0.5)
        let day0 = Date(timeIntervalSince1970: 0)
        tracker.recordSelection(elementID: "el1", now: day0)
        let day2 = day0.addingTimeInterval(2 * 24 * 60 * 60)
        tracker.recordSelection(elementID: "el2", now: day2) // triggers decay pass
        XCTAssertEqual(tracker.score(for: "el1"), 0.25, accuracy: 0.0001) // 1 * 0.5^2
    }

    func test_multipleDecayPassesDoNotCompound() {
        let tracker = FrequencyTracker(storeURL: tempStoreURL(), decayFactor: 0.5)
        let day0 = Date(timeIntervalSince1970: 0)
        tracker.recordSelection(elementID: "el1", now: day0)

        let day2 = day0.addingTimeInterval(2 * 24 * 60 * 60)
        tracker.recordSelection(elementID: "el2", now: day2) // triggers first decay pass on el1

        let day4 = day0.addingTimeInterval(4 * 24 * 60 * 60)
        tracker.recordSelection(elementID: "el3", now: day4) // triggers second decay pass on el1

        // A single continuous 4-day decay from day0, not two compounding partial decays
        XCTAssertEqual(tracker.score(for: "el1"), 1 * pow(0.5, 4.0), accuracy: 0.0001)
    }

    func test_persistAndReloadRoundTrips() throws {
        let url = tempStoreURL()
        let tracker = FrequencyTracker(storeURL: url)
        tracker.recordSelection(elementID: "el1")
        try tracker.persist()

        let reloaded = FrequencyTracker(storeURL: url)
        XCTAssertEqual(reloaded.score(for: "el1"), 1)
    }

    func test_resetClearsScores() {
        let tracker = FrequencyTracker(storeURL: tempStoreURL())
        tracker.recordSelection(elementID: "el1")
        tracker.reset()
        XCTAssertEqual(tracker.score(for: "el1"), 0)
    }
}
