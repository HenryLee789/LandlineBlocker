import Foundation
import PhotosUI
import SwiftUI

@MainActor
final class BlacklistViewModel: ObservableObject {
    @Published var inputText = ""
    @Published var includeMobiles = false
    @Published var records: [BlockedNumberRecord] = []
    @Published var parsedNumbers: [ParsedNumber] = []
    @Published var importStats = ImportStats()
    @Published var existingNumberCount = 0
    @Published var statusMessage: String?
    @Published var isProcessing = false
    @Published var extensionStatus: CallDirectoryExtensionStatus = .unknown
    @Published var exportFile: ExportFile?

    private let ocrService = OCRService()

    func loadInitialData() async {
        do {
            records = try await Task.detached(priority: .userInitiated) {
                try BlacklistStorage.loadThrowing()
            }.value
            existingNumberCount = 0
            statusMessage = records.isEmpty ? "黑名单为空，可以开始导入号码。" : "已加载 \(records.count) 个黑名单号码。"
        } catch {
            statusMessage = "读取黑名单失败：\(error.localizedDescription)"
        }
    }

    func refreshExtensionStatus() async {
        extensionStatus = await CallDirectoryReloader.shared.enabledStatus()
    }

    func importPastedText() {
        let lines = inputText.components(separatedBy: .newlines)
        guard lines.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            statusMessage = "请先粘贴号码文本。"
            return
        }

        importLines(lines)
    }

    func importPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }

        Task {
            isProcessing = true
            defer { isProcessing = false }

            do {
                let ocrResult = try await ocrService.recognizeText(from: item)
                var parseInputs = ocrResult.observationTexts
                if !ocrResult.fullText.isEmpty {
                    parseInputs.append(ocrResult.fullText)
                }

                let shouldIncludeMobiles = self.includeMobiles
                let result = await Task.detached(priority: .userInitiated) {
                    NumberParser.parseLines(parseInputs, includeMobiles: shouldIncludeMobiles)
                }.value

                await applyImportResult(result)
            } catch {
                statusMessage = "OCR 识别失败：\(error.localizedDescription)"
            }
        }
    }

    func delete(_ record: BlockedNumberRecord) {
        let updated = records.filter { $0.id != record.id }
        Task {
            await saveRecords(updated, successMessage: "黑名单已更新，请点击刷新拦截库使系统生效。")
        }
    }

    func clearAll() {
        Task {
            await saveRecords([], successMessage: "黑名单已清空，请点击刷新拦截库使系统生效。")
        }
    }

    func reloadCallDirectory() {
        Task {
            isProcessing = true
            defer { isProcessing = false }

            await refreshExtensionStatus()
            let result = await CallDirectoryReloader.shared.reloadExtension()
            switch result {
            case .success:
                statusMessage = "拦截库刷新成功"
            case .failure(let failure):
                statusMessage = "刷新失败：\(failure.message)"
            }
            await refreshExtensionStatus()
        }
    }

    func exportBlacklist() {
        do {
            let url = try ShareExport.makeBlacklistTextFile(records: records)
            exportFile = ExportFile(url: url)
            statusMessage = "导出文件已准备好。"
        } catch {
            statusMessage = "导出失败：\(error.localizedDescription)"
        }
    }

    private func importLines(_ lines: [String]) {
        Task {
            isProcessing = true
            defer { isProcessing = false }

            let shouldIncludeMobiles = self.includeMobiles
            let result = await Task.detached(priority: .userInitiated) {
                NumberParser.parseLines(lines, includeMobiles: shouldIncludeMobiles)
            }.value

            await applyImportResult(result)
        }
    }

    private func applyImportResult(_ result: ImportResult) async {
        parsedNumbers = result.parsedNumbers
        importStats = result.stats

        let mergeResult = mergeImportedRecords(result.records, into: records)
        existingNumberCount = mergeResult.existingDuplicateCount

        let duplicateSuffix = mergeResult.existingDuplicateCount > 0 ? " 已存在号码 \(mergeResult.existingDuplicateCount) 个。" : ""
        await saveRecords(mergeResult.records, successMessage: "黑名单已更新，请点击刷新拦截库使系统生效。\(duplicateSuffix)")
    }

    private func mergeImportedRecords(_ imported: [BlockedNumberRecord], into existing: [BlockedNumberRecord]) -> MergeResult {
        var seen = Set<String>()
        var merged: [BlockedNumberRecord] = []
        var existingNormalized = Set<String>()
        var existingDuplicateCount = 0

        for record in existing {
            if seen.insert(record.normalized).inserted {
                merged.append(record)
                existingNormalized.insert(record.normalized)
            }
        }

        for record in imported {
            if existingNormalized.contains(record.normalized) {
                existingDuplicateCount += 1
            }

            if seen.insert(record.normalized).inserted {
                merged.append(record)
            }
        }

        return MergeResult(records: merged, existingDuplicateCount: existingDuplicateCount)
    }

    private func saveRecords(_ updated: [BlockedNumberRecord], successMessage: String) async {
        do {
            try await Task.detached(priority: .userInitiated) {
                try BlacklistStorage.save(updated)
            }.value
            records = updated
            statusMessage = successMessage
        } catch {
            statusMessage = "保存黑名单失败：\(error.localizedDescription)"
        }
    }
}

private struct MergeResult {
    let records: [BlockedNumberRecord]
    let existingDuplicateCount: Int
}
