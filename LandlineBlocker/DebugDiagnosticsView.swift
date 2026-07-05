#if DEBUG
import Foundation
import SwiftUI

struct DebugDiagnosticsView: View {
    let recordsCount: Int
    let extensionStatus: CallDirectoryExtensionStatus
    let lastReloadResult: String

    private var appGroupDiagnostic: AppGroupDiagnostic {
        AppGroupDiagnostic.current()
    }

    var body: some View {
        let diagnostic = appGroupDiagnostic

        VStack(alignment: .leading, spacing: 10) {
            Text("Debug 诊断")
                .font(.headline)

            diagnosticRow("黑名单数量", "\(recordsCount)")
            diagnosticRow("App Group", diagnostic.isAccessible ? "可访问" : "不可访问")
            diagnosticRow("blacklist.json", diagnostic.fileExists ? "存在" : "不存在")
            diagnosticRow("文件路径", diagnostic.filePath)
            diagnosticRow("Extension ID", SharedConfig.extensionIdentifier)
            diagnosticRow("Extension 状态", extensionStatus.displayName)
            diagnosticRow("最近 reload", lastReloadResult)

            if let errorDescription = diagnostic.errorDescription {
                Text(errorDescription)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
        }
        .font(.footnote)
        .padding()
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func diagnosticRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .textSelection(.enabled)
        }
    }
}

private struct AppGroupDiagnostic {
    let isAccessible: Bool
    let fileExists: Bool
    let filePath: String
    let errorDescription: String?

    static func current() -> AppGroupDiagnostic {
        do {
            let url = try BlacklistStorage.blacklistFileURL()
            return AppGroupDiagnostic(
                isAccessible: true,
                fileExists: FileManager.default.fileExists(atPath: url.path),
                filePath: url.path,
                errorDescription: nil
            )
        } catch {
            return AppGroupDiagnostic(
                isAccessible: false,
                fileExists: false,
                filePath: "无法获取",
                errorDescription: error.localizedDescription
            )
        }
    }
}
#endif
