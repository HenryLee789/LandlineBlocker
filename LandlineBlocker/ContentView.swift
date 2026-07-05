import PhotosUI
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = BlacklistViewModel()
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    importSection
                    statusSection
                    statsSection
                    actionSection
                    blacklistSection
                    guideSection
                }
                .padding()
            }
            .navigationTitle("固话拦截")
            .navigationBarTitleDisplayMode(.inline)
            .overlay {
                if viewModel.isProcessing {
                    ZStack {
                        Color.black.opacity(0.15).ignoresSafeArea()
                        ProgressView("处理中...")
                            .padding(20)
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
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
    }

    private var importSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("导入号码")
                .font(.headline)

            TextEditor(text: $viewModel.inputText)
                .frame(minHeight: 140)
                .padding(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.35))
                )
                .accessibilityLabel("粘贴号码文本")

            Toggle("包含手机号", isOn: $viewModel.includeMobiles)

            HStack(spacing: 12) {
                Button {
                    viewModel.importPastedText()
                } label: {
                    Label("导入粘贴文本", systemImage: "text.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isProcessing)

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("截图 OCR 导入", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isProcessing)
            }
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("扩展状态")
                    .font(.headline)
                Spacer()
                Text(viewModel.extensionStatus.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(viewModel.extensionStatus.tintColor)
            }

            if viewModel.extensionStatus != .enabled {
                Text("未启用时，请去“设置 > 电话 > 来电阻止与身份识别”手动开启本 App 的来电拦截扩展。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let message = viewModel.statusMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(message.contains("失败") || message.contains("错误") ? Color.red : Color.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("导入统计")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
                statsRow("识别文本行数", viewModel.importStats.totalLines)
                statsRow("固话号码", viewModel.importStats.landlineCount)
                statsRow("手机号", viewModel.importStats.mobileCount)
                statsRow("默认跳过手机号", viewModel.importStats.skippedMobileCount)
                statsRow("格式异常", viewModel.importStats.invalidCount)
                statsRow("重复号码", viewModel.importStats.duplicateCount)
                statsRow("已存在号码", viewModel.existingNumberCount)
                statsRow("去重后号码", viewModel.importStats.finalCount)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func statsRow(_ title: String, _ value: Int) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .fontWeight(.semibold)
        }
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Button(role: .destructive) {
                    viewModel.clearAll()
                } label: {
                    Label("清空全部", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.records.isEmpty || viewModel.isProcessing)

                Button {
                    viewModel.exportBlacklist()
                } label: {
                    Label("导出 txt", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.records.isEmpty || viewModel.isProcessing)
            }

            Button {
                viewModel.reloadCallDirectory()
            } label: {
                Label("刷新拦截库", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isProcessing)
        }
    }

    private var blacklistSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("黑名单列表")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.records.count) 个")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if viewModel.records.isEmpty {
                Text("暂无号码。请粘贴文本或导入截图识别号码。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.records) { record in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.raw)
                                    .font(.subheadline)
                                    .lineLimit(2)
                                Text(record.normalized)
                                    .font(.footnote.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                viewModel.delete(record)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("删除号码")
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    private var guideSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("使用说明")
                .font(.headline)
            Text("本 App 只拦截已经导入并保存到黑名单里的具体号码。iOS 不允许第三方 App 读取系统通话记录，也不允许实时监听来电或按括号格式动态拦截。")
            Text("导入、删除或清空后，请点击“刷新拦截库”，系统侧才会更新。安装后还需要去“设置 > 电话 > 来电阻止与身份识别”手动开启扩展。")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.bottom, 24)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
