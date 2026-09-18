import Foundation

public struct FrequencyRecord: Codable, Equatable {
    public var count: Double
    public var lastUsed: Date
}

public final class FrequencyTracker {
    private var records: [String: FrequencyRecord]
    private let decayFactor: Double
    private let storeURL: URL

    public init(storeURL: URL, decayFactor: Double = 0.98) {
        self.storeURL = storeURL
        self.decayFactor = decayFactor
        self.records = Self.load(from: storeURL)
    }

    public func score(for elementID: String) -> Double {
        records[elementID]?.count ?? 0
    }

    public func recordSelection(elementID: String, now: Date = Date()) {
        applyDecayIfNeeded(now: now)
        var record = records[elementID] ?? FrequencyRecord(count: 0, lastUsed: now)
        record.count += 1
        record.lastUsed = now
        records[elementID] = record
    }

    public func reset() {
        records = [:]
    }

    public func persist() throws {
        let data = try JSONEncoder().encode(records)
        try data.write(to: storeURL, options: .atomic)
    }

    private func applyDecayIfNeeded(now: Date) {
        let calendar = Calendar(identifier: .gregorian)
        for (id, record) in records {
            let days = calendar.dateComponents([.day], from: record.lastUsed, to: now).day ?? 0
            guard days > 0 else { continue }
            var updated = record
            updated.count *= pow(decayFactor, Double(days))
            updated.lastUsed = now
            records[id] = updated
        }
    }

    private static func load(from url: URL) -> [String: FrequencyRecord] {
        guard let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: FrequencyRecord].self, from: data)) ?? [:]
    }
}
