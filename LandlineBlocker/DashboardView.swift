import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: BlacklistViewModel
    let openImport: () -> Void
    let openBlacklist: () -> Void

    var body: some View {
        NavigationStack {
            LBScreen {
                HeroStatusCard(
                    status: viewModel.extensionStatus,
                    statusMessage: viewModel.statusMessage,
                    recordsCount: viewModel.records.count,
                    lastReloadResult: viewModel.lastReloadResult,
                    reload: viewModel.reloadCallDirectory,
                    isProcessing: viewModel.isProcessing
                )

                QuickActionGrid(
                    openImport: openImport,
                    openBlacklist: openBlacklist,
                    reload: viewModel.reloadCallDirectory,
                    export: viewModel.exportBlacklist,
                    canExport: !viewModel.records.isEmpty,
                    isProcessing: viewModel.isProcessing
                )

                ImportStatsOverview(stats: viewModel.importStats, existingCount: viewModel.existingNumberCount)

                RecentRecognitionPanel(parsedNumbers: viewModel.parsedNumbers)

                SystemLimitCard()
            }
            .navigationTitle("固话拦截")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct HeroStatusCard: View {
    let status: CallDirectoryExtensionStatus
    let statusMessage: String?
    let recordsCount: Int
    let lastReloadResult: String
    let reload: () -> Void
    let isProcessing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Label(status.displayName, systemImage: status.iconName)
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text(statusMessage ?? "导入号码后刷新拦截库")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.74))
                        .lineLimit(2)
                }

                Spacer(minLength: 16)

                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(recordsCount)")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("已收录")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.white)
            }

            HStack(spacing: 10) {
                Button(action: reload) {
                    Label("刷新拦截库", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.teal)
                .disabled(isProcessing)

                StatusChip(text: lastReloadResult, systemImage: "clock")
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.38, blue: 0.40),
                    Color(red: 0.02, green: 0.18, blue: 0.23),
                    Color(red: 0.11, green: 0.12, blue: 0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct StatusChip: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(.white.opacity(0.86))
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(.white.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct QuickActionGrid: View {
    let openImport: () -> Void
    let openBlacklist: () -> Void
    let reload: () -> Void
    let export: () -> Void
    let canExport: Bool
    let isProcessing: Bool

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            DashboardActionButton(title: "导入号码", systemImage: "text.badge.plus", tint: .teal, action: openImport)
            DashboardActionButton(title: "黑名单", systemImage: "phone.down", tint: .indigo, action: openBlacklist)
            DashboardActionButton(title: "刷新", systemImage: "arrow.clockwise", tint: .green, action: reload)
                .disabled(isProcessing)
            DashboardActionButton(title: "导出", systemImage: "square.and.arrow.up", tint: .orange, action: export)
                .disabled(!canExport || isProcessing)
        }
    }
}

private struct DashboardActionButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.headline)
                    .frame(width: 30, height: 30)
                    .background(tint.opacity(0.14))
                    .foregroundStyle(tint)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            .padding(12)
            .frame(minHeight: 58)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

private struct ImportStatsOverview: View {
    let stats: ImportStats
    let existingCount: Int

    var body: some View {
        LBPanel {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle("识别概览", systemImage: "chart.bar")

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    MetricTile(title: "固话", value: stats.landlineCount, systemImage: "phone", tint: .teal)
                    MetricTile(title: "0 开头收录", value: stats.landlineCount, systemImage: "zero.circle", tint: .green)
                    MetricTile(title: "已跳过手机", value: stats.skippedMobileCount, systemImage: "iphone.slash", tint: .orange)
                    MetricTile(title: "已存在", value: existingCount, systemImage: "checkmark.seal", tint: .indigo)
                }
            }
        }
    }
}

private struct RecentRecognitionPanel: View {
    let parsedNumbers: [ParsedNumber]

    var body: some View {
        LBPanel {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle("最近识别", systemImage: "sparkles")

                if parsedNumbers.isEmpty {
                    EmptyStateView(
                        systemImage: "tray",
                        title: "暂无识别结果",
                        subtitle: "导入文本或截图后会显示最近结果"
                    )
                } else {
                    VStack(spacing: 8) {
                        ForEach(Array(parsedNumbers.prefix(3).enumerated()), id: \.offset) { _, parsed in
                            RecognitionRow(parsed: parsed)
                        }
                    }
                }
            }
        }
    }
}

private struct SystemLimitCard: View {
    var body: some View {
        LBPanel {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle("系统限制", systemImage: "lock.shield")
                Text("iOS 只能拦截已经提交给 Call Directory 的完整号码；导入或删除后需要刷新拦截库。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
