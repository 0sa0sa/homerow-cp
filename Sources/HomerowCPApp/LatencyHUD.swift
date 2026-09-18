import Foundation

final class LatencyHUD {
    private var samples: [TimeInterval] = []

    func report(elapsed: TimeInterval) {
        samples.append(elapsed)
        let ms = Int(elapsed * 1000)
        print("[HomerowCP] activation latency: \(ms)ms (avg over \(samples.count): \(Int(samples.reduce(0, +) / Double(samples.count) * 1000))ms)")
    }
}
