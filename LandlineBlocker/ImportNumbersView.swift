import PhotosUI
import SwiftUI

struct ImportNumbersView: View {
    @ObservedObject var viewModel: BlacklistViewModel
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            LBScreen {
                ImportComposerPanel(
                    inputText: $viewModel.inputText,
                    includeMobiles: $viewModel.includeMobiles,
                    importText: viewModel.importPastedText,
                    selectedPhotoItem: $selectedPhotoItem,
                    isProcessing: viewModel.isProcessing
                )

                ParsePreviewPanel(parsedNumbers: viewModel.parsedNumbers)

                DetailedStatsPanel(stats: viewModel.importStats, existingCount: viewModel.existingNumberCount)
            }
            .navigationTitle("导入")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: selectedPhotoItem) { item in
                viewModel.importPhoto(item)
                selectedPhotoItem = nil
            }
        }
    }
}

private struct ImportComposerPanel: View {
    @Binding var inputText: String
    @Binding var includeMobiles: Bool
    let importText: () -> Void
    @Binding var selectedPhotoItem: PhotosPickerItem?
    let isProcessing: Bool

    private var canImportText: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isProcessing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("号码导入中心")
                    .font(.title2.weight(.bold))
                Text("所有 0 开头完整号码会直接进入待刷新黑名单")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $inputText)
                    .frame(minHeight: 180)
                    .padding(10)
                    .scrollContentBackground(.hidden)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.16))
                    }
                    .accessibilityLabel("粘贴号码文本")

                if inputText.isEmpty {
                    Text("粘贴号码文本，或从截图 OCR 识别")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }
            }

            HStack(spacing: 10) {
                Toggle(isOn: $includeMobiles) {
                    Label("包含手机号", systemImage: "iphone")
                        .font(.subheadline.weight(.semibold))
                }
                .toggleStyle(.switch)
            }

            HStack(spacing: 10) {
                Button(action: importText) {
                    Label("导入文本", systemImage: "text.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canImportText)

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("OCR", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isProcessing)
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [
                    Color(.secondarySystemGroupedBackground),
                    Color(.tertiarySystemGroupedBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct ParsePreviewPanel: View {
    let parsedNumbers: [ParsedNumber]

    var body: some View {
        LBPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle("识别预览", systemImage: "checklist")
                    Spacer()
                    Text("\(parsedNumbers.count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                if parsedNumbers.isEmpty {
                    EmptyStateView(
                        systemImage: "doc.text.magnifyingglass",
                        title: "等待导入",
                        subtitle: "导入后会显示识别、跳过和异常原因"
                    )
                } else {
                    VStack(spacing: 8) {
                        ForEach(Array(parsedNumbers.prefix(8).enumerated()), id: \.offset) { _, parsed in
                            RecognitionRow(parsed: parsed)
                        }

                        if parsedNumbers.count > 8 {
                            Text("另有 \(parsedNumbers.count - 8) 条结果已收起")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

private struct DetailedStatsPanel: View {
    let stats: ImportStats
    let existingCount: Int

    var body: some View {
        LBPanel {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle("导入统计", systemImage: "number")

                VStack(spacing: 8) {
                    StatLine(title: "文本行数", value: stats.totalLines)
                    StatLine(title: "固话 / 0 开头号码", value: stats.landlineCount)
                    StatLine(title: "手机号", value: stats.mobileCount)
                    StatLine(title: "默认跳过手机号", value: stats.skippedMobileCount)
                    StatLine(title: "格式异常", value: stats.invalidCount)
                    StatLine(title: "重复号码", value: stats.duplicateCount)
                    StatLine(title: "已存在号码", value: existingCount)
                    StatLine(title: "可提交号码", value: stats.finalCount)
                }
            }
        }
    }
}
