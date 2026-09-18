import SwiftUI
import HomerowCPAccessibility

public struct OnboardingView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            Text("アクセシビリティ権限が必要です")
                .font(.title2.bold())
            Text("キーボードでUIを操作するには、システム設定でこのアプリにアクセシビリティ権限を許可してください。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("システム設定を開く") {
                AccessibilityPermission.openSystemSettings()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(width: 360)
    }
}
