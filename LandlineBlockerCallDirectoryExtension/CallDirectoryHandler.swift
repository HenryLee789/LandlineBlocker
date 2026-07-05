import Foundation
import CallKit

final class CallDirectoryHandler: CXCallDirectoryProvider {
    override func beginRequest(with context: CXCallDirectoryExtensionContext) {
        context.delegate = self
        addBlockingPhoneNumbers(to: context)
        context.completeRequest()
    }

    private func addBlockingPhoneNumbers(to context: CXCallDirectoryExtensionContext) {
        let records = BlacklistStorage.loadOrEmpty()
        let normalizedValues = records
            .map { $0.normalized.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && Self.containsOnlyASCIIDigits($0) }

        var convertedNumbers: [CXCallDirectoryPhoneNumber] = []
        convertedNumbers.reserveCapacity(normalizedValues.count)

        for value in normalizedValues {
            if let number = Int64(value), number > 0 {
                convertedNumbers.append(number)
            }
        }

        let sortedUniqueNumbers = Set(convertedNumbers).sorted()

        #if DEBUG
        print("[LandlineBlocker] blacklist records: \(records.count)")
        print("[LandlineBlocker] valid normalized values: \(normalizedValues.count)")
        print("[LandlineBlocker] Int64 converted values: \(convertedNumbers.count)")
        print("[LandlineBlocker] unique sorted values: \(sortedUniqueNumbers.count)")
        print("[LandlineBlocker] submitting blocking entries: \(sortedUniqueNumbers.count)")
        #endif

        var previousNumber: CXCallDirectoryPhoneNumber?
        for number in sortedUniqueNumbers {
            #if DEBUG
            if let previousNumber {
                assert(number > previousNumber, "CallKit blocking entries must be strictly ascending.")
            }
            #endif

            context.addBlockingEntry(withNextSequentialPhoneNumber: number)
            previousNumber = number
        }
    }

    private static func containsOnlyASCIIDigits(_ value: String) -> Bool {
        value.unicodeScalars.allSatisfy { scalar in
            scalar.value >= 48 && scalar.value <= 57
        }
    }
}

extension CallDirectoryHandler: CXCallDirectoryExtensionContextDelegate {
    func requestFailed(for extensionContext: CXCallDirectoryExtensionContext, withError error: Error) {
        #if DEBUG
        print("[LandlineBlocker] Call Directory request failed: \(error.localizedDescription)")
        #endif
    }
}
