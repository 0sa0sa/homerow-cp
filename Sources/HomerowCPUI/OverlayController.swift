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
    private var hostingView: NSHostingView<OverlayRootView>?
    /// `ClickKind` is derived from the modifier flags held during the keystroke that
    /// completed the label (see `handleKeyPress`): Shift -> right click, Option -> double
    /// click, Command -> command click, no modifier -> left click.
    public var onSelect: ((ClickableElement, ClickKind) -> Void)?
    public var onDismiss: (() -> Void)?

    public init() {}

    public func show(elements: [ClickableElement], assignments: [LabelAssignment], on screenFrame: CGRect) {
        dismiss()
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
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.panel = panel
        refreshOverlayContent()
        panel.orderFrontRegardless()
    }

    public func handleKeyPress(character: Character, modifierFlags: NSEvent.ModifierFlags = []) {
        let normalizedCharacter = Character(String(character).lowercased())
        let result = router.handle(character: normalizedCharacter, currentQuery: query, assignments: assignments)
        switch result {
        case .selected(let elementID):
            let element = elementsByID[elementID]
            dismiss()
            if let element {
                onSelect?(element, clickKind(for: modifierFlags))
            }
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
        guard panel != nil else { return }
        panel?.orderOut(nil)
        panel = nil
        hostingView = nil
        onDismiss?()
    }

    private func refreshOverlayContent() {
        let rootView = OverlayRootView(elements: currentElements, assignments: assignments, matchedPrefix: query)
        if let hostingView {
            hostingView.rootView = rootView
        } else {
            let newHostingView = NSHostingView(rootView: rootView)
            hostingView = newHostingView
            panel?.contentView = newHostingView
        }
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
