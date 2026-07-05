import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: BlacklistViewModel
    @Binding var appearanceMode: AppAppearanceMode

    var body: some View {
        NavigationStack {
            LBScreen {
                AppearancePanel(appearanceMode: $appearanceMode)

                ExtensionInfoPanel(
                    status: viewModel.extensionStatus,
                    lastReloadResult: viewModel.lastReloadResult
                )

                PrivacyPanel()

                #if DEBUG
                DebugDiagnosticsView(
                    recordsCount: viewModel.records.count,
                    extensionStatus: viewModel.extensionStatus,
                    lastReloadResult: viewModel.lastReloadResult
                )
                #endif
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct AppearancePanel: View {
    @Binding var appearanceMode: AppAppearanceMode

    var body: some View {
        LBPanel {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle("外观", systemImage: "circle.lefthalf.filled")

                Picker("外观", selection: $appearanceMode) {
                    ForEach(AppAppearanceMode.allCases) { mode in
                        Label(mode.displayName, systemImage: mode.iconName)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }
}

private struct ExtensionInfoPanel: View {
    let status: CallDirectoryExtensionStatus
    let lastReloadResult: String

    var body: some View {
        LBPanel {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle("扩展", systemImage: "shield")

                SettingsRow(title: "状态", value: status.displayName, systemImage: status.iconName, tint: status.tintColor)
                SettingsRow(title: "Extension ID", value: SharedConfig.extensionIdentifier, systemImage: "puzzlepiece.extension", tint: .indigo)
                SettingsRow(title: "最近刷新", value: lastReloadResult, systemImage: "clock", tint: .orange)
            }
        }
    }
}

private struct PrivacyPanel: View {
    var body: some View {
        LBPanel {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle("隐私", systemImage: "hand.raised")

                Text("App 不读取通话记录，不监听来电，也不上传号码。黑名单保存在本机 App Group 中。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct SettingsRow: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.13))
                .foregroundStyle(tint)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(title)
                .font(.subheadline.weight(.semibold))

            Spacer(minLength: 12)

            Text(value)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }
}
