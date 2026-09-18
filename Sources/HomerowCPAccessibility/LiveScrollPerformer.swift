import CoreGraphics

public struct LiveScrollPerformer {
    public init() {}

    public func scroll(dx: Double, dy: Double) {
        let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: Int32(-dy), wheel2: Int32(-dx), wheel3: 0)
        event?.post(tap: .cghidEventTap)
    }
}
