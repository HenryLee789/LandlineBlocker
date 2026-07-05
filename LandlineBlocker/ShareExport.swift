import Foundation
import SwiftUI
import UIKit

struct ExportFile: Identifiable {
    let id = UUID()
    let url: URL
}

enum ShareExport {
    static func makeBlacklistTextFile(records: [BlockedNumberRecord]) throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let fileName = "LandlineBlocker_Blacklist_\(formatter.string(from: Date())).txt"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        let content = records.map(\.normalized).joined(separator: "\n")
        let finalContent = content.isEmpty ? "" : content + "\n"
        let data = Data(finalContent.utf8)
        try data.write(to: url, options: [.atomic])
        return url
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
