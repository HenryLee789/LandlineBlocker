import XCTest
@testable import LandlineBlocker

final class NumberParserTests: XCTestCase {
    func testRequiredLandlineNormalizationSamples() {
        assertSingleNormalized("(021) 5404 1579", expected: "862154041579")
        assertSingleNormalized("(0371) 2254 4004", expected: "8637122544004")
        assertSingleNormalized("(021) 9522 127", expected: "86219522127")
        assertSingleNormalized("021-5404-1579", expected: "862154041579")
        assertSingleNormalized("021 5404 1579", expected: "862154041579")
        assertSingleNormalized("0371 2254 4004", expected: "8637122544004")
        assertSingleNormalized("+86 21 5404 1579", expected: "862154041579")
        assertSingleNormalized("+86 371 2254 4004", expected: "8637122544004")
        assertSingleNormalized("86 21 5404 1579", expected: "862154041579")
        assertSingleNormalized("86 371 2254 4004", expected: "8637122544004")
    }

    func testMobileSkippedByDefault() {
        let result = NumberParser.parseLines(["13800138000"], includeMobiles: false)
        XCTAssertTrue(result.records.isEmpty)
        XCTAssertEqual(result.stats.skippedMobileCount, 1)
        XCTAssertEqual(result.parsedNumbers.first?.kind, .mobile)
        XCTAssertEqual(result.parsedNumbers.first?.isValid, false)
    }

    func testMobileIncludedWhenEnabled() {
        assertSingleNormalized("13800138000", expected: "8613800138000", includeMobiles: true)
        assertSingleNormalized("156 1781 2630", expected: "8615617812630", includeMobiles: true)
    }

    func testContextCandidateExtraction() {
        assertSingleNormalized("未知来电 (021) 5404 1579 中国 上海", expected: "862154041579")
        assertSingleNormalized("昨天 (0371) 2254 4004 河南 郑州/开封", expected: "8637122544004")
        assertSingleNormalized("(0851) 8897 6367 中国 贵州", expected: "8685188976367")
    }

    func testFullWidthDigitsAreParsed() {
        assertSingleNormalized("（０２１）５４０４ １５７９", expected: "862154041579")
    }

    func testAnyZeroPrefixedPhoneNumberIsParsedForBlocking() {
        assertSingleNormalized("09522 127", expected: "869522127")
        assertSingleNormalized("09999-1234-5678", expected: "86999912345678")
        assertSingleNormalized("+86 09522 127", expected: "869522127")
        assertSingleNormalized("来电 0 9522 127", expected: "869522127")
    }

    func testSpacedMobileSkippedByDefault() {
        let candidates = NumberParser.extractCandidates(from: "156 1781 2630", includeMobiles: false)
        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates.first?.kind, .mobile)
        XCTAssertEqual(candidates.first?.isValid, false)

        let result = NumberParser.parseLines(["156 1781 2630"], includeMobiles: false)
        XCTAssertTrue(result.records.isEmpty)
        XCTAssertEqual(result.stats.skippedMobileCount, 1)
    }

    func testDuplicateNumbersKeepFirstRecordOnly() {
        let result = NumberParser.parseLines(
            [
                "未知来电 (021) 5404 1579 中国 上海",
                "021-5404-1579",
                "+86 21 5404 1579"
            ],
            includeMobiles: false
        )

        XCTAssertEqual(result.records.count, 1)
        XCTAssertEqual(result.records.first?.normalized, "862154041579")
        XCTAssertEqual(result.records.first?.raw, "(021) 5404 1579")
        XCTAssertEqual(result.stats.duplicateCount, 2)
    }

    func testExtensionSortingLogicIsStrictlyAscending() {
        let records = [
            BlockedNumberRecord(raw: "(0371) 2254 4004", normalized: "8637122544004"),
            BlockedNumberRecord(raw: "(021) 5404 1579", normalized: "862154041579"),
            BlockedNumberRecord(raw: "duplicate", normalized: "862154041579"),
            BlockedNumberRecord(raw: "bad", normalized: "not-a-number")
        ]

        let sorted = NumberParser.sortedUniquePhoneNumbersForCallKit(from: records)
        XCTAssertEqual(sorted, [862154041579, 8637122544004])

        for index in sorted.indices.dropFirst() {
            XCTAssertGreaterThan(sorted[index], sorted[sorted.index(before: index)])
        }
    }

    private func assertSingleNormalized(_ input: String, expected: String, includeMobiles: Bool = false, file: StaticString = #filePath, line: UInt = #line) {
        let candidates = NumberParser.extractCandidates(from: input, includeMobiles: includeMobiles)
        let validCandidates = candidates.filter(\.isValid)
        XCTAssertEqual(validCandidates.first?.normalized, expected, file: file, line: line)

        let result = NumberParser.parseLines([input], includeMobiles: includeMobiles)
        XCTAssertEqual(result.records.first?.normalized, expected, file: file, line: line)
    }
}
