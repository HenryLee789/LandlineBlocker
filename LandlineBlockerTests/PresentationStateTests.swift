import SwiftUI
import XCTest
@testable import LandlineBlocker

final class PresentationStateTests: XCTestCase {
    func testAppearanceModeMapsToExpectedColorScheme() {
        XCTAssertNil(AppAppearanceMode.system.colorScheme)
        XCTAssertEqual(AppAppearanceMode.light.colorScheme, .light)
        XCTAssertEqual(AppAppearanceMode.dark.colorScheme, .dark)
    }

    func testMaskedNumberKeepsUsefulPrefixAndSuffix() {
        XCTAssertEqual(PhoneNumberPresentation.masked("862154041579"), "8621 **** 1579")
        XCTAssertEqual(PhoneNumberPresentation.masked("8637122544004"), "8637 ***** 4004")
        XCTAssertEqual(PhoneNumberPresentation.masked("1234567"), "1234567")
    }

    func testMaskedTextHidesLongDigitRuns() {
        XCTAssertEqual(
            PhoneNumberPresentation.maskedDigits(in: "上海 (021) 5404 1579"),
            "上海 8621 **** 1579"
        )
        XCTAssertEqual(
            PhoneNumberPresentation.maskedDigits(in: "备注 12 34"),
            "备注 12 34"
        )
    }

    func testRecordSearchMatchesRawAndNormalizedNumbers() {
        let records = [
            BlockedNumberRecord(raw: "上海 (021) 5404 1579", normalized: "862154041579"),
            BlockedNumberRecord(raw: "郑州 (0371) 2254 4004", normalized: "8637122544004")
        ]

        XCTAssertEqual(
            BlacklistListFilter.filtered(records, query: "5404").map(\.normalized),
            ["862154041579"]
        )
        XCTAssertEqual(
            BlacklistListFilter.filtered(records, query: "郑州").map(\.normalized),
            ["8637122544004"]
        )
        XCTAssertEqual(
            BlacklistListFilter.filtered(records, query: "  ").map(\.normalized),
            ["862154041579", "8637122544004"]
        )
    }
}
