import AppKit
import SwiftUI
import HomerowCPCore

public final class OverlayController {
    private var panel: NSPanel?
    private let router = OverlayInputRouter()
    private var query = ""
    private var currentElements: [ClickableElement] = []
    private var assignments: [LabelAssignment] = []
    private var elementsByID: [String: ClickableElement] = [:]
    private var keyMonitor: Any?
    /// `ClickKind` is derived from the modifier flags held during the keystroke that
    /// completed the label (see `handleKeyPress`): Shift -> right click, Option -> double
    /// click, Command -> command click, no modifier -> left click.
    public var onSelect: ((ClickableElement, ClickKind) -> Void)?

    public init() {}

    public func show(elements: [ClickableElement], assignments: [LabelAssignment], on screenFrame: CGRect) {
        self.currentElements = elements
        self.assignments = assignments
        self.elementsByID = Dictionary(uniqueKeysWithValues: elements.map { ($0.stableID, $0) })
        query = ""

        let panel = NSPanel(
            contentRect: screenFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        self.panel = panel
        refreshOverlayContent()
        panel.orderFrontRegardless()

        // The panel is a non-activating NSPanel so it never steals focus from the app
        // underneath; keystrokes are instead captured system-wide via a global monitor
        // (requires the Accessibility permission already granted for AXUIElement access)
        // and routed into `handleKeyPress`, which drives the SwiftUI overlay purely from
        // state (`query`) rather than first responder chains.
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let scalar = event.charactersIgnoringModifiers?.unicodeScalars.first else { return }
            self.handleKeyPress(character: Character(scalar), modifierFlags: event.modifierFlags)
        }
    }

    public func handleKeyPress(character: Character, modifierFlags: NSEvent.ModifierFlags = []) {
        let result = router.handle(character: character, currentQuery: query, assignments: assignments)
        switch result {
        case .selected(let elementID):
            if let element = elementsByID[elementID] {
                onSelect?(element, clickKind(for: modifierFlags))
            }
            dismiss()
        case .updatedQuery(let newQuery):
            query = newQuery
            refreshOverlayContent()
        case .noMatch:
            query = ""
            refreshOverlayContent()
        case .dismiss:
            dismiss()
        }
    }

    public func dismiss() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        panel?.orderOut(nil)
        panel = nil
    }

    private func refreshOverlayContent() {
        guard let panel else { return }
        let rootView = OverlayRootView(elements: currentElements, assignments: assignments, matchedPrefix: query)
        panel.contentView = NSHostingView(rootView: rootView)
    }

    private func clickKind(for modifierFlags: NSEvent.ModifierFlags) -> ClickKind {
        if modifierFlags.contains(.shift) { return .right }
        if modifierFlags.contains(.option) { return .double }
        if modifierFlags.contains(.command) { return .command }
        return .left
    }
}

private struct OverlayRootView: View {
    let elements: [ClickableElement]
    let assignments: [LabelAssignment]
    let matchedPrefix: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(assignments, id: \.elementID) { assignment in
                if let element = elements.first(where: { $0.stableID == assignment.elementID }) {
                    HintLabelView(label: assignment.label, matchedPrefix: matchedPrefix, isPrioritized: false)
                        .position(x: element.frame.x, y: element.frame.y)
                }
            }
        }
    }
}
