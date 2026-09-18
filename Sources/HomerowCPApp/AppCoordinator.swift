import AppKit
import SwiftUI
import HomerowCPCore
import HomerowCPAccessibility
import HomerowCPUI

final class AppCoordinator {
    private let cache = WindowCache()
    private let indexer: AccessibilityIndexer
    private let hotkeyManager = HotkeyManager()
    private let scrollHotkeyManager = HotkeyManager()
    private let overlay = OverlayController()
    private let clickPerformer = LiveClickPerformer()
    private let scrollController = ScrollController()
    private let scrollPerformer = LiveScrollPerformer()
    private let inputTap = InputTapController()
    private let frequencyTracker: FrequencyTracker
    private let labelEngine = LabelAssignmentEngine()
    private var previousLabels: [String: String] = [:]
    private let latencyHUD = LatencyHUD()
    private var statusItem: NSStatusItem?
    private var preferencesWindow: NSWindow?

    init() {
        indexer = AccessibilityIndexer(cache: cache)
        let storeURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HomerowCP", isDirectory: true)
        try? FileManager.default.createDirectory(at: storeURL, withIntermediateDirectories: true)
        frequencyTracker = FrequencyTracker(storeURL: storeURL.appendingPathComponent("frequency.json"))
    }

    func start() {
        setUpStatusItem()
        guard AccessibilityPermission.isTrusted(promptIfNeeded: true) else {
            presentOnboarding()
            return
        }
        indexer.start()

        overlay.onSelect = { [weak self] element, kind in
            guard let self else { return }
            if let axElement = self.indexer.axElement(for: element.stableID) {
                self.clickPerformer.perform(kind: kind, on: axElement, frame: element.frame)
            }
            self.frequencyTracker.recordSelection(elementID: element.stableID)
            try? self.frequencyTracker.persist()
        }
        overlay.onDismiss = { [weak self] in self?.inputTap.exitToIdle() }

        inputTap.onKeyDown = { [weak self] character, modifierFlags in
            self?.routeTapKey(character, modifierFlags: modifierFlags)
        }

        let activationCombo = KeyComboParser.parse("cmd+shift+space")!
        let scrollCombo = KeyComboParser.parse("cmd+shift+j")!
        inputTap.registerPassthroughHotkeys([activationCombo, scrollCombo])

        hotkeyManager.onActivate = { [weak self] in self?.activateOverlay() }
        hotkeyManager.register(combo: activationCombo)

        scrollHotkeyManager.onActivate = { [weak self] in self?.enterScrollMode() }
        scrollHotkeyManager.register(combo: scrollCombo)
    }

    private func routeTapKey(_ character: Character, modifierFlags: NSEvent.ModifierFlags) {
        switch inputTap.mode {
        case .idle:
            return
        case .hints:
            overlay.handleKeyPress(character: character, modifierFlags: modifierFlags)
        case .scroll:
            if character == "\u{1B}" {
                exitScrollMode()
                return
            }
            guard let direction = scrollController.direction(for: character) else { return }
            let delta = scrollController.delta(for: direction)
            scrollPerformer.scroll(dx: delta.dx, dy: delta.dy)
        }
    }

    private func enterScrollMode() {
        guard inputTap.mode != .scroll else { return }
        if inputTap.mode == .hints { overlay.dismiss() }
        inputTap.enter(.scroll)
    }

    private func exitScrollMode() {
        guard inputTap.mode == .scroll else { return }
        inputTap.exitToIdle()
    }

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.title = "⌨"

        let menu = NSMenu()
        menu.addItem(withTitle: "Preferences...", action: #selector(showPreferences), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit HomerowCP", action: #selector(quit), keyEquivalent: "q")
        for menuItem in menu.items { menuItem.target = self }
        item.menu = menu
        statusItem = item
    }

    @objc private func showPreferences() {
        if let preferencesWindow {
            preferencesWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let view = PreferencesView(onResetFrequencyData: { [weak self] in
            self?.frequencyTracker.reset()
            try? self?.frequencyTracker.persist()
            self?.previousLabels = [:]
        })
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "HomerowCP Preferences"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        preferencesWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func activateOverlay() {
        exitScrollMode()
        let started = Date()
        guard let screen = NSScreen.main else { return }
        guard let key = indexer.lastCachedKey,
              let elements = cache.elements(for: key) else { return }
        guard key.bundleID == NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return }

        var scores: [String: Double] = [:]
        for element in elements { scores[element.stableID] = frequencyTracker.score(for: element.stableID) }
        let assignments = labelEngine.assignLabels(elements: elements, frequencyScores: scores, previousAssignments: previousLabels)
        previousLabels = Dictionary(uniqueKeysWithValues: assignments.map { ($0.elementID, $0.label) })

        overlay.show(elements: elements, assignments: assignments, on: screen.frame)
        inputTap.enter(.hints)
        latencyHUD.report(elapsed: Date().timeIntervalSince(started))
    }

    private func presentOnboarding() {
        let window = NSWindow(contentViewController: NSHostingController(rootView: OnboardingView()))
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
