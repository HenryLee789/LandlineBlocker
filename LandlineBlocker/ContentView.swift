import PhotosUI
import SwiftUI

struct ContentView: View {
    @AppStorage("appearanceMode") private var appearanceModeRaw = AppAppearanceMode.system.rawValue
    @StateObject private var viewModel = BlacklistViewModel()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var searchText = ""

    private var appearanceMode: AppAppearanceMode {
        AppAppearanceMode(rawValue: appearanceModeRaw) ?? .system
    }

    private var appearanceModeBinding: Binding<AppAppearanceMode> {
        Binding(
            get: { appearanceMode },
            set: { appearanceModeRaw = $0.rawValue }
        )
    }

    private var filteredRecords: [BlockedNumberRecord] {
        BlacklistListFilter.filtered(viewModel.records, query: searchText)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    summarySection
                    importSection
                    parsePreviewSection
                    statsSection
                    actionsSection
                    blacklistSection
                    systemLimitsSection
                    #if DEBUG
                    DebugDiagnosticsView(
                        recordsCount: viewModel.records.count,
                        extensionStatus: viewModel.extensionStatus,
                        lastReloadResult: viewModel.lastReloadResult
                    )
                    #endif
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("固话拦截")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("外观", selection: appearanceModeBinding) {
                            ForEach(AppAppearanceMode.allCases) { mode in
                                Label(mode.displayName, systemImage: mode.iconName)
                                    .tag(mode)
                            }
                        }
                    } label: {
                        Image(systemName: appearanceMode.iconName)
                    }
                    .accessibilityLabel("外观")
                }
            }
            .overlay {
                if viewModel.isProcessing {
                    ProcessingOverlay()
                }
            }
            .sheet(item: $viewModel.exportFile) { file in
                ActivityView(activityItems: [file.url])
            }
            .task {
                await viewModel.loadInitialData()
                await viewModel.refreshExtensionStatus()
            }
            .onChange(of: selectedPhotoItem) { item in
                viewModel.importPhoto(item)
                selectedPhotoItem = nil
            }
        }
        .preferredColorScheme(appearanceMode.colorScheme)
    }

    private var summarySection: some View {
        AppPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: statusIconName)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(viewModel.extensionStatus.tintColor)
                        .frame(width: 36, height: 36)
                        .background(viewModel.extensionStatus.tintColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("扩展状态")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(viewModel.extensionStatus.displayName)
                            .font(.headline)
                        if let message = viewModel.statusMessage {
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(message.isFailureMessage ? Color.red : Color.secondary)
                                .lineLimit(3)
                                .textSelection(.enabled)
                        }
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(viewModel.records.count)")
                            .font(.title2.weight(.bold))
                            .monospacedDigit()
                        Text("黑名单")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if viewModel.extensionStatus != .enabled {
                    Label("需要在系统设置里开启来电阻止扩展", systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var importSection: some View {
        AppPanel {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "导入号码", systemImage: "square.and.arrow.down")

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $viewModel.inputText)
                        .frame(minHeight: 132)
                        .padding(8)
                        .scrollContentBackground(.hidden)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.2))
                        }
                        .accessibilityLabel("粘贴号码文本")

                    if viewModel.inputText.isEmpty {
                        Text("粘贴通话截图识别出的文本，或直接输入号码")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }

                Toggle(isOn: $viewModel.includeMobiles) {
                    Label("包含手机号", systemImage: "iphone")
                }

                HStack(spacing: 10) {
                    Button {
                        viewModel.importPastedText()
                    } label: {
                        Label("导入文本", systemImage: "text.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isProcessing)

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label("OCR", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isProcessing)
                }
            }
        }
    }

    @ViewBuilder
    private var parsePreviewSection: some View {
        if !viewModel.parsedNumbers.isEmpty {
            AppPanel {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "识别预览", systemImage: "checklist")

                    ForEach(Array(viewModel.parsedNumbers.prefix(5).enumerated()), id: \.offset) { _, parsed in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Image(systemName: parsed.isValid ? "checkmark.circle.fill" : "minus.circle.fill")
                                .foregroundStyle(parsed.isValid ? Color.green : Color.orange)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(parsedPreviewTitle(parsed))
                                    .font(.subheadline.weight(.semibold))
                                Text(parsed.reason)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }

                    if viewModel.parsedNumbers.count > 5 {
                        Text("另有 \(viewModel.parsedNumbers.count - 5) 条结果已收起")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var statsSection: some View {
        AppPanel {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "导入统计", systemImage: "chart.bar")

                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 9) {
                    statsRow("文本行数", viewModel.importStats.totalLines)
                    statsRow("固话号码", viewModel.importStats.landlineCount)
                    statsRow("手机号", viewModel.importStats.mobileCount)
                    statsRow("已跳过手机", viewModel.importStats.skippedMobileCount)
                    statsRow("格式异常", viewModel.importStats.invalidCount)
                    statsRow("重复号码", viewModel.importStats.duplicateCount)
                    statsRow("已存在", viewModel.existingNumberCount)
                    statsRow("可提交", viewModel.importStats.finalCount)
                }
            }
        }
    }

    private func statsRow(_ title: String, _ value: Int) -> some View {
        GridRow {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
        }
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button(role: .destructive) {
                    viewModel.clearAll()
                } label: {
                    Label("清空", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.records.isEmpty || viewModel.isProcessing)

                Button {
                    viewModel.exportBlacklist()
                } label: {
                    Label("导出", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.records.isEmpty || viewModel.isProcessing)
            }

            Button {
                viewModel.reloadCallDirectory()
            } label: {
                Label("刷新拦截库", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isProcessing)
        }
    }

    private var blacklistSection: some View {
        AppPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionHeader(title: "黑名单", systemImage: "phone.down")
                    Spacer()
                    Text("\(filteredRecords.count)/\(viewModel.records.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                if !viewModel.records.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("搜索号码或备注", text: $searchText)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                if viewModel.records.isEmpty {
                    EmptyStateView(
                        systemImage: "tray",
                        title: "暂无号码",
                        subtitle: "导入文本或截图后，号码会显示在这里"
                    )
                } else if filteredRecords.isEmpty {
                    EmptyStateView(
                        systemImage: "magnifyingglass",
                        title: "没有匹配结果",
                        subtitle: "换一个号码片段或地区文字再试"
                    )
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredRecords) { record in
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(PhoneNumberPresentation.masked(record.normalized))
                                        .font(.subheadline.weight(.semibold).monospacedDigit())
                                    Text(PhoneNumberPresentation.maskedDigits(in: record.raw))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    viewModel.delete(record)
                                } label: {
                                    Image(systemName: "trash")
                                        .frame(width: 30, height: 30)
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("删除号码")
                            }
                            .padding(.vertical, 9)
                            .padding(.horizontal, 10)
                            .background(Color(.tertiarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
        }
    }

    private var systemLimitsSection: some View {
        AppPanel {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "系统限制", systemImage: "lock.shield")
                Text("iOS 只允许扩展提交明确号码。导入、删除或清空后，需要刷新拦截库；扩展也必须在“设置 > 电话 > 来电阻止与身份识别”中开启。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusIconName: String {
        switch viewModel.extensionStatus {
        case .enabled:
            return "checkmark.shield.fill"
        case .disabled:
            return "shield.slash"
        case .unknown:
            return "questionmark.circle"
        case .unavailable:
            return "exclamationmark.triangle.fill"
        }
    }

    private func parsedPreviewTitle(_ parsed: ParsedNumber) -> String {
        if parsed.isValid {
            return PhoneNumberPresentation.masked(parsed.normalized)
        }
        if parsed.kind == .mobile {
            return "手机号已跳过"
        }
        return "未识别号码"
    }
}

private struct AppPanel<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct SectionHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
    }
}

private struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

private struct ProcessingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.16).ignoresSafeArea()
            ProgressView("处理中...")
                .padding(20)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

private extension String {
    var isFailureMessage: Bool {
        contains("失败") || contains("错误")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
