import Foundation

public func bucketedPosition(x: Double, y: Double, bucketSize: Double = 50) -> (row: Int, col: Int) {
    (row: Int((y / bucketSize).rounded()), col: Int((x / bucketSize).rounded()))
}

public enum StableIDGenerator {
    public static func makeID(
        bundleID: String,
        windowRole: String,
        elementRole: String,
        title: String?,
        approximatePosition: (row: Int, col: Int)
    ) -> String {
        let titlePart = (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(bundleID)|\(windowRole)|\(elementRole)|\(titlePart)|\(approximatePosition.row),\(approximatePosition.col)"
    }
}
