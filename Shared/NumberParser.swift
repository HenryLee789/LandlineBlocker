import Foundation

public enum ParsedNumberKind: String, Codable, Hashable, Sendable {
    case landline
    case mobile
    case invalid
}

public struct ParsedNumber: Hashable, Sendable {
    public let raw: String
    public let normalized: String
    public let kind: ParsedNumberKind
    public let isValid: Bool
    public let reason: String

    public init(raw: String, normalized: String, kind: ParsedNumberKind, isValid: Bool, reason: String) {
        self.raw = raw
        self.normalized = normalized
        self.kind = kind
        self.isValid = isValid
        self.reason = reason
    }
}

public struct ImportStats: Equatable, Sendable {
    public var totalLines: Int
    public var landlineCount: Int
    public var mobileCount: Int
    public var skippedMobileCount: Int
    public var invalidCount: Int
    public var duplicateCount: Int
    public var finalCount: Int

    public init(
        totalLines: Int = 0,
        landlineCount: Int = 0,
        mobileCount: Int = 0,
        skippedMobileCount: Int = 0,
        invalidCount: Int = 0,
        duplicateCount: Int = 0,
        finalCount: Int = 0
    ) {
        self.totalLines = totalLines
        self.landlineCount = landlineCount
        self.mobileCount = mobileCount
        self.skippedMobileCount = skippedMobileCount
        self.invalidCount = invalidCount
        self.duplicateCount = duplicateCount
        self.finalCount = finalCount
    }
}

public struct ImportResult: Sendable {
    public let records: [BlockedNumberRecord]
    public let parsedNumbers: [ParsedNumber]
    public let stats: ImportStats

    public init(records: [BlockedNumberRecord], parsedNumbers: [ParsedNumber], stats: ImportStats) {
        self.records = records
        self.parsedNumbers = parsedNumbers
        self.stats = stats
    }
}

public enum NumberParser {
    private static let twoDigitAreaCodes: Set<String> = ["10", "20", "21", "22", "23", "24", "25", "27", "28", "29"]
    private static let area2Pattern = "(?:10|2[0-57-9])"
    private static let area3Pattern = "(?:[3-9]\\d{2})"
    private static let separatorPattern = "[\\s\\-.]*"
    private static let localPattern = "\\d{3,4}[\\s\\-.]*\\d{3,4}"

    private static var landlineWithCountryPattern: String {
        "(?<!\\d)\\+?86\(separatorPattern)[（(]?0?(?:\(area2Pattern)|\(area3Pattern))[）)]?\(separatorPattern)\(localPattern)(?!\\d)"
    }

    private static var domesticLandlinePattern: String {
        "(?<!\\d)[（(]?0(?:\(area2Pattern)|\(area3Pattern))[）)]?\(separatorPattern)\(localPattern)(?!\\d)"
    }

    private static var mobileWithCountryPattern: String {
        "(?<!\\d)\\+?86\(separatorPattern)1\\d{2}\(separatorPattern)\\d{4}\(separatorPattern)\\d{4}(?!\\d)"
    }

    private static var domesticMobilePattern: String {
        "(?<!\\d)1\\d{2}\(separatorPattern)\\d{4}\(separatorPattern)\\d{4}(?!\\d)"
    }

    public static func parseLines(_ lines: [String], includeMobiles: Bool) -> ImportResult {
        var parsedNumbers: [ParsedNumber] = []
        var recordsByNormalized: [String: BlockedNumberRecord] = [:]
        var normalizedOrder: [String] = []
        var stats = ImportStats(totalLines: lines.count)

        for line in lines {
            let candidates = extractCandidates(from: line, includeMobiles: includeMobiles)

            if candidates.isEmpty {
                if containsPhoneLikeDigits(line) {
                    stats.invalidCount += 1
                    parsedNumbers.append(
                        ParsedNumber(
                            raw: line.trimmingCharacters(in: .whitespacesAndNewlines),
                            normalized: "",
                            kind: .invalid,
                            isValid: false,
                            reason: "未识别为支持的中国大陆固话或手机号"
                        )
                    )
                }
                continue
            }

            for parsed in candidates {
                parsedNumbers.append(parsed)

                if parsed.isValid {
                    switch parsed.kind {
                    case .landline:
                        stats.landlineCount += 1
                    case .mobile:
                        stats.mobileCount += 1
                    case .invalid:
                        stats.invalidCount += 1
                    }

                    if recordsByNormalized[parsed.normalized] == nil {
                        recordsByNormalized[parsed.normalized] = BlockedNumberRecord(raw: parsed.raw, normalized: parsed.normalized)
                        normalizedOrder.append(parsed.normalized)
                    } else {
                        stats.duplicateCount += 1
                    }
                } else if parsed.kind == .mobile {
                    stats.skippedMobileCount += 1
                } else {
                    stats.invalidCount += 1
                }
            }
        }

        let records = normalizedOrder.compactMap { recordsByNormalized[$0] }
        stats.finalCount = records.count
        return ImportResult(records: records, parsedNumbers: parsedNumbers, stats: stats)
    }

    public static func extractCandidates(from text: String, includeMobiles: Bool) -> [ParsedNumber] {
        let matches = collectCandidateMatches(from: text)
        var selectedMatches: [CandidateMatch] = []

        for match in matches {
            let overlapsExisting = selectedMatches.contains { selected in
                NSIntersectionRange(selected.range, match.range).length > 0
            }

            if !overlapsExisting {
                selectedMatches.append(match)
            }
        }

        var seenKeys = Set<String>()
        var parsedNumbers: [ParsedNumber] = []

        for match in selectedMatches.sorted(by: { $0.range.location < $1.range.location }) {
            let parsed = parseCandidate(match.raw, includeMobiles: includeMobiles)
            let key = parsed.isValid ? "valid:\(parsed.normalized)" : "invalid:\(parsed.raw):\(parsed.reason)"
            if seenKeys.insert(key).inserted {
                parsedNumbers.append(parsed)
            }
        }

        return parsedNumbers
    }

    public static func sortedUniquePhoneNumbersForCallKit(from records: [BlockedNumberRecord]) -> [Int64] {
        let numbers = records.compactMap { record -> Int64? in
            let value = record.normalized.trimmingCharacters(in: .whitespacesAndNewlines)
            guard containsOnlyASCIIDigits(value) else { return nil }
            return Int64(value)
        }
        return Set(numbers).sorted()
    }

    private static func collectCandidateMatches(from text: String) -> [CandidateMatch] {
        let searchText = normalizeFullWidthDigits(in: text)
        let patterns: [(pattern: String, priority: Int)] = [
            (landlineWithCountryPattern, 0),
            (domesticLandlinePattern, 1),
            (mobileWithCountryPattern, 2),
            (domesticMobilePattern, 3)
        ]

        var matches: [CandidateMatch] = []
        for item in patterns {
            matches.append(contentsOf: regexMatches(pattern: item.pattern, in: searchText, originalText: text, priority: item.priority))
        }

        return matches.sorted { lhs, rhs in
            if lhs.range.location != rhs.range.location {
                return lhs.range.location < rhs.range.location
            }
            if lhs.range.length != rhs.range.length {
                return lhs.range.length > rhs.range.length
            }
            return lhs.priority < rhs.priority
        }
    }

    private static func regexMatches(pattern: String, in searchText: String, originalText: String, priority: Int) -> [CandidateMatch] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let nsSearchText = searchText as NSString
        let nsOriginalText = originalText as NSString
        let range = NSRange(location: 0, length: nsSearchText.length)
        return regex.matches(in: searchText, range: range).compactMap { match in
            guard match.range.location != NSNotFound else { return nil }
            guard NSMaxRange(match.range) <= nsOriginalText.length else { return nil }
            let raw = nsOriginalText.substring(with: match.range).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !raw.isEmpty else { return nil }
            return CandidateMatch(raw: raw, range: match.range, priority: priority)
        }
    }

    private static func parseCandidate(_ raw: String, includeMobiles: Bool) -> ParsedNumber {
        let digits = asciiDigits(from: raw)

        guard !digits.isEmpty else {
            return ParsedNumber(raw: raw, normalized: "", kind: .invalid, isValid: false, reason: "不包含数字")
        }

        if digits.hasPrefix("86") {
            var national = String(digits.dropFirst(2))
            if national.hasPrefix("0") {
                national = String(national.dropFirst())
            }

            if isLandlineNationalNumber(national) {
                return ParsedNumber(raw: raw, normalized: "86" + national, kind: .landline, isValid: true, reason: "已识别为大陆固话")
            }

            if isMobileNationalNumber(national) {
                if includeMobiles {
                    return ParsedNumber(raw: raw, normalized: "86" + national, kind: .mobile, isValid: true, reason: "已识别为手机号")
                }
                return ParsedNumber(raw: raw, normalized: "", kind: .mobile, isValid: false, reason: "手机号已按设置跳过")
            }

            return ParsedNumber(raw: raw, normalized: "", kind: .invalid, isValid: false, reason: "86 前缀号码格式不支持")
        }

        if digits.hasPrefix("0") {
            let national = String(digits.dropFirst())
            if isLandlineNationalNumber(national) {
                return ParsedNumber(raw: raw, normalized: "86" + national, kind: .landline, isValid: true, reason: "已识别为大陆固话")
            }
            return ParsedNumber(raw: raw, normalized: "", kind: .invalid, isValid: false, reason: "大陆固话格式不支持")
        }

        if isMobileNationalNumber(digits) {
            if includeMobiles {
                return ParsedNumber(raw: raw, normalized: "86" + digits, kind: .mobile, isValid: true, reason: "已识别为手机号")
            }
            return ParsedNumber(raw: raw, normalized: "", kind: .mobile, isValid: false, reason: "手机号已按设置跳过")
        }

        return ParsedNumber(raw: raw, normalized: "", kind: .invalid, isValid: false, reason: "号码格式不支持")
    }

    private static func isLandlineNationalNumber(_ digits: String) -> Bool {
        for areaCode in twoDigitAreaCodes {
            if digits.hasPrefix(areaCode) {
                let local = String(digits.dropFirst(areaCode.count))
                if local.count == 7 || local.count == 8 {
                    return true
                }
            }
        }

        guard digits.count >= 10 else { return false }
        let areaCodeEndIndex = digits.index(digits.startIndex, offsetBy: 3)
        let areaCode = String(digits[..<areaCodeEndIndex])
        guard let first = areaCode.first, isDigitBetweenThreeAndNine(first) else {
            return false
        }

        let local = String(digits[areaCodeEndIndex...])
        return local.count == 7 || local.count == 8
    }

    private static func isMobileNationalNumber(_ digits: String) -> Bool {
        guard digits.count == 11, digits.first == "1" else { return false }
        guard let second = digits.dropFirst().first else { return false }
        return isDigitBetweenThreeAndNine(second)
    }

    private static func containsPhoneLikeDigits(_ text: String) -> Bool {
        asciiDigits(from: text).count >= 7
    }

    private static func asciiDigits(from text: String) -> String {
        var digits = ""
        for scalar in text.unicodeScalars {
            if scalar.value >= 48 && scalar.value <= 57 {
                digits.unicodeScalars.append(scalar)
            } else if scalar.value >= 0xFF10 && scalar.value <= 0xFF19 {
                let asciiValue = scalar.value - 0xFF10 + 48
                if let asciiScalar = UnicodeScalar(asciiValue) {
                    digits.unicodeScalars.append(asciiScalar)
                }
            }
        }
        return digits
    }

    private static func normalizeFullWidthDigits(in text: String) -> String {
        var normalized = ""
        normalized.reserveCapacity(text.count)

        for scalar in text.unicodeScalars {
            if scalar.value >= 0xFF10 && scalar.value <= 0xFF19 {
                let asciiValue = scalar.value - 0xFF10 + 48
                if let asciiScalar = UnicodeScalar(asciiValue) {
                    normalized.unicodeScalars.append(asciiScalar)
                }
            } else {
                normalized.unicodeScalars.append(scalar)
            }
        }

        return normalized
    }

    private static func containsOnlyASCIIDigits(_ value: String) -> Bool {
        value.unicodeScalars.allSatisfy { scalar in
            scalar.value >= 48 && scalar.value <= 57
        }
    }

    private static func isDigitBetweenThreeAndNine(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first else { return false }
        return scalar.value >= 51 && scalar.value <= 57
    }
}

private struct CandidateMatch {
    let raw: String
    let range: NSRange
    let priority: Int
}
