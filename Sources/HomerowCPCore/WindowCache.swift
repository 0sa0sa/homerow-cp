import Foundation

public struct WindowKey: Hashable {
    public let bundleID: String
    public let windowID: Int

    public init(bundleID: String, windowID: Int) {
        self.bundleID = bundleID
        self.windowID = windowID
    }
}

public final class WindowCache {
    private var storage: [WindowKey: [ClickableElement]] = [:]
    private let lock = NSLock()

    public init() {}

    public func elements(for key: WindowKey) -> [ClickableElement]? {
        lock.lock(); defer { lock.unlock() }
        return storage[key]
    }

    public func update(_ elements: [ClickableElement], for key: WindowKey) {
        lock.lock(); defer { lock.unlock() }
        storage[key] = elements
    }

    public func invalidate(_ key: WindowKey) {
        lock.lock(); defer { lock.unlock() }
        storage.removeValue(forKey: key)
    }
}
