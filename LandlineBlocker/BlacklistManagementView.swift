import SwiftUI

struct BlacklistManagementView: View {
    @ObservedObject var viewModel: BlacklistViewModel
    @Binding var searchText: String

    private var filteredRecords: [BlockedNumberRecord] {
        BlacklistListFilter.filtered(viewModel.records, query: searchText)
    }

    var body: some View {
        NavigationStack {
            LBScreen {
                BlacklistSummaryPanel(
                    totalCount: viewModel.records.count,
                    filteredCount: filteredRecords.count,
                    reload: viewModel.reloadCallDirectory,
                    export: viewModel.exportBlacklist,
                    clearAll: viewModel.clearAll,
                    isProcessing: viewModel.isProcessing
                )

                SearchPanel(searchText: $searchText)
                    .opacity(viewModel.records.isEmpty ? 0.45 : 1)
                    .disabled(viewModel.records.isEmpty)

                BlacklistRecordsPanel(
                    records: viewModel.records,
                    filteredRecords: filteredRecords,
                    delete: viewModel.delete
                )
            }
            .navigationTitle("黑名单")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct BlacklistSummaryPanel: View {
    let totalCount: Int
    let filteredCount: Int
    let reload: () -> Void
    let export: () -> Void
    let clearAll: () -> Void
    let isProcessing: Bool

    var body: some View {
        LBPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(totalCount)")
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("当前黑名单号码")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 6) {
                        Text("\(filteredCount)")
                            .font(.title3.weight(.bold))
                            .monospacedDigit()
                        Text("当前显示")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 10) {
                    Button(action: reload) {
                        Label("刷新", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isProcessing)

                    Button(action: export) {
                        Label("导出", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(totalCount == 0 || isProcessing)

                    Button(role: .destructive, action: clearAll) {
                        Image(systemName: "trash")
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.bordered)
                    .disabled(totalCount == 0 || isProcessing)
                    .accessibilityLabel("清空黑名单")
                }
            }
        }
    }
}

private struct SearchPanel: View {
    @Binding var searchText: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("搜索号码或备注", text: $searchText)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("清空搜索")
            }
        }
        .padding(13)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct BlacklistRecordsPanel: View {
    let records: [BlockedNumberRecord]
    let filteredRecords: [BlockedNumberRecord]
    let delete: (BlockedNumberRecord) -> Void

    var body: some View {
        LBPanel {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle("号码列表", systemImage: "list.bullet")

                if records.isEmpty {
                    EmptyStateView(
                        systemImage: "phone.badge.plus",
                        title: "还没有黑名单",
                        subtitle: "先去导入页添加 0 开头号码"
                    )
                } else if filteredRecords.isEmpty {
                    EmptyStateView(
                        systemImage: "magnifyingglass",
                        title: "没有匹配结果",
                        subtitle: "换一个号码片段或备注再试"
                    )
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredRecords) { record in
                            BlacklistRecordRow(record: record, delete: delete)
                        }
                    }
                }
            }
        }
    }
}

private struct BlacklistRecordRow: View {
    let record: BlockedNumberRecord
    let delete: (BlockedNumberRecord) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "phone.down.circle.fill")
                .font(.title3)
                .foregroundStyle(.teal)

            VStack(alignment: .leading, spacing: 4) {
                Text(PhoneNumberPresentation.masked(record.normalized))
                    .font(.system(.headline, design: .rounded).monospacedDigit())
                Text(PhoneNumberPresentation.maskedDigits(in: record.raw))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(role: .destructive) {
                delete(record)
            } label: {
                Image(systemName: "trash")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("删除号码")
        }
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
