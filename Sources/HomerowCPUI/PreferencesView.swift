import SwiftUI
import HomerowCPCore

public struct PreferencesView: View {
    public enum Tab: String, CaseIterable, Identifiable {
        case general = "General"
        case keybindings = "Keybindings"
        case appearance = "Appearance"
        case frequencyData = "Frequency Data"
        case about = "About"
        public var id: String { rawValue }
    }

    @State private var selectedTab: Tab = .general
    let onResetFrequencyData: () -> Void

    public init(onResetFrequencyData: @escaping () -> Void) {
        self.onResetFrequencyData = onResetFrequencyData
    }

    public var body: some View {
        NavigationSplitView {
            List(Tab.allCases, selection: $selectedTab) { tab in
                Text(tab.rawValue).tag(tab)
            }
            .navigationSplitViewColumnWidth(160)
        } detail: {
            switch selectedTab {
            case .general:
                Text("General settings placeholder")
            case .keybindings:
                Text("Keybinding recorder placeholder")
            case .appearance:
                Text("Appearance settings placeholder")
            case .frequencyData:
                VStack(alignment: .leading, spacing: 12) {
                    Text("学習した頻度データをリセットできます。")
                    Button("学習データをリセット", role: .destructive) {
                        onResetFrequencyData()
                    }
                }
                .padding()
            case .about:
                Text("HomerowCP v0.1.0")
            }
        }
        .frame(width: 560, height: 360)
    }
}
