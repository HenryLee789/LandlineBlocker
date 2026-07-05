import CallKit
import Foundation
import SwiftUI

enum CallDirectoryExtensionStatus: Equatable, Sendable {
    case enabled
    case disabled
    case unknown
    case unavailable(String)

    var displayName: String {
        switch self {
        case .enabled:
            return "已启用"
        case .disabled:
            return "未启用"
        case .unknown:
            return "未知"
        case .unavailable:
            return "不可用"
        }
    }

    var tintColor: Color {
        switch self {
        case .enabled:
            return .green
        case .disabled:
            return .orange
        case .unknown:
            return .secondary
        case .unavailable:
            return .red
        }
    }
}

struct CallDirectoryReloadFailure: Error, Sendable {
    let localizedDescription: String
    let domain: String
    let code: Int

    var message: String {
        "\(localizedDescription)（\(domain) code \(code)）"
    }
}

final class CallDirectoryReloader {
    static let shared = CallDirectoryReloader()

    private init() {}

    func enabledStatus() async -> CallDirectoryExtensionStatus {
        await withCheckedContinuation { continuation in
            CXCallDirectoryManager.sharedInstance.getEnabledStatusForExtension(withIdentifier: SharedConfig.extensionIdentifier) { status, error in
                if let error {
                    continuation.resume(returning: .unavailable(error.localizedDescription))
                    return
                }

                switch status {
                case .enabled:
                    continuation.resume(returning: .enabled)
                case .disabled:
                    continuation.resume(returning: .disabled)
                case .unknown:
                    continuation.resume(returning: .unknown)
                @unknown default:
                    continuation.resume(returning: .unknown)
                }
            }
        }
    }

    func reloadExtension() async -> Result<Void, CallDirectoryReloadFailure> {
        await withCheckedContinuation { continuation in
            CXCallDirectoryManager.sharedInstance.reloadExtension(withIdentifier: SharedConfig.extensionIdentifier) { error in
                if let error {
                    let nsError = error as NSError
                    let failure = CallDirectoryReloadFailure(
                        localizedDescription: error.localizedDescription,
                        domain: nsError.domain,
                        code: nsError.code
                    )
                    continuation.resume(returning: .failure(failure))
                    return
                }

                continuation.resume(returning: .success(()))
            }
        }
    }
}
