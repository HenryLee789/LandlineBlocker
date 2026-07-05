import Foundation

enum PhoneNumberPresentation {
    static func masked(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 8 else { return trimmed }

        let prefix = String(trimmed.prefix(4))
        let suffix = String(trimmed.suffix(4))
        let hiddenCount = trimmed.count - prefix.count - suffix.count
        return "\(prefix) \(String(repeating: "*", count: hiddenCount)) \(suffix)"
    }

    static func maskedDigits(in text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidates = NumberParser.extractCandidates(from: trimmed, includeMobiles: true).filter(\.isValid)
        guard !candidates.isEmpty else { return trimmed }

        var result = trimmed
        for candidate in candidates {
            result = result.replacingOccurrences(of: candidate.raw, with: masked(candidate.normalized))
        }
        return result
    }
}

enum BlacklistListFilter {
    static func filtered(_ records: [BlockedNumberRecord], query: String) -> [BlockedNumberRecord] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return records }

        let queryDigits = trimmed.unicodeScalars.filter { scalar in
            scalar.value >= 48 && scalar.value <= 57
        }

        return records.filter { record in
            if record.raw.localizedCaseInsensitiveContains(trimmed) {
                return true
            }

            if record.normalized.localizedCaseInsensitiveContains(trimmed) {
                return true
            }

            if !queryDigits.isEmpty {
                return record.normalized.contains(String(String.UnicodeScalarView(queryDigits)))
            }

            return false
        }
    }
}
