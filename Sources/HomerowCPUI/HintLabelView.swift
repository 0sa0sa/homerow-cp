import SwiftUI
import HomerowCPCore

public struct HintLabelView: View {
    let label: String
    let matchedPrefix: String
    let isPrioritized: Bool

    public init(label: String, matchedPrefix: String, isPrioritized: Bool) {
        self.label = label
        self.matchedPrefix = matchedPrefix
        self.isPrioritized = isPrioritized
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(label.enumerated()), id: \.offset) { index, char in
                Text(String(char))
                    .foregroundColor(index < matchedPrefix.count ? .accentColor : .primary)
            }
        }
        .font(.system(size: 12, weight: .bold, design: .monospaced))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(isPrioritized ? Color.accentColor.opacity(0.6) : Color.clear, lineWidth: 1)
        )
        .transition(.asymmetric(insertion: .scale(scale: 0.8).combined(with: .opacity), removal: .opacity))
        .animation(.spring(response: 0.15, dampingFraction: 0.8), value: matchedPrefix)
    }
}
