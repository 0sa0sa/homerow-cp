import AppKit
import ApplicationServices
import HomerowCPCore

public final class AccessibilityIndexer {
    private let cache: WindowCache
    private var observer: AXObserver?
    private var currentAppElement: AXUIElement?
    private var currentBundleID: String?
    private var workspaceToken: NSObjectProtocol?
    private let stateLock = NSLock()
    private var _lastCachedKey: WindowKey?
    private var axElementLookup: [String: AXUIElement] = [:]

    public init(cache: WindowCache) {
        self.cache = cache
    }

    public var lastCachedKey: WindowKey? {
        stateLock.lock(); defer { stateLock.unlock() }
        return _lastCachedKey
    }

    /// The live `AXUIElement` for a previously scanned `ClickableElement.stableID`,
    /// valid only until the next rescan of that window. Used by `ActionExecutor`/
    /// `LiveClickPerformer` to actually perform a click on the element the user selected.
    public func axElement(for stableID: String) -> AXUIElement? {
        stateLock.lock(); defer { stateLock.unlock() }
        return axElementLookup[stableID]
    }

    public func start() {
        workspaceToken = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.attach(to: app)
        }
        if let frontmost = NSWorkspace.shared.frontmostApplication {
            attach(to: frontmost)
        }
    }

    public func stop() {
        if let workspaceToken {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceToken)
        }
        observer = nil
    }

    private func attach(to app: NSRunningApplication) {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        currentAppElement = appElement
        currentBundleID = app.bundleIdentifier

        var axObserver: AXObserver?
        let callback: AXObserverCallback = { _, _, _, refcon in
            guard let refcon else { return }
            let indexer = Unmanaged<AccessibilityIndexer>.fromOpaque(refcon).takeUnretainedValue()
            indexer.rescanCurrentWindow()
        }
        AXObserverCreate(app.processIdentifier, callback, &axObserver)
        guard let axObserver else { return }
        observer = axObserver

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for notification in [
            kAXFocusedWindowChangedNotification,
            kAXUIElementDestroyedNotification,
            kAXLayoutChangedNotification,
            kAXWindowResizedNotification,
        ] {
            AXObserverAddNotification(axObserver, appElement, notification as CFString, refcon)
        }
        CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(axObserver), .defaultMode)

        rescanCurrentWindow()
    }

    private func rescanCurrentWindow() {
        guard let appElement = currentAppElement, let bundleID = currentBundleID else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            var windowValue: AnyObject?
            guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowValue) == .success,
                  let windowValue else { return }
            let axWindow = windowValue as! AXUIElement
            let node = LiveAXNode(element: axWindow)
            let scanner = ClickableElementScanner(bundleID: bundleID, windowRole: node.role)
            let pairs = scanner.scanPaired(root: node)
            let elements = pairs.map(\.element)
            var lookup: [String: AXUIElement] = [:]
            for pair in pairs {
                if let liveNode = pair.node as? LiveAXNode {
                    lookup[pair.element.stableID] = liveNode.underlyingElement
                }
            }

            var windowIDValue: AnyObject?
            AXUIElementCopyAttributeValue(axWindow, "AXWindowNumber" as CFString, &windowIDValue)
            let windowID = (windowIDValue as? Int) ?? 0
            let key = WindowKey(bundleID: bundleID, windowID: windowID)

            self.cache.update(elements, for: key)
            self.stateLock.lock()
            self._lastCachedKey = key
            self.axElementLookup = lookup
            self.stateLock.unlock()
        }
    }
}
