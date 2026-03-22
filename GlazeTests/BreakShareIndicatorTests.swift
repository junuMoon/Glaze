import XCTest
@testable import Glaze

final class BreakShareIndicatorTests: XCTestCase {
    func testUsesWarningLevelBelowHalfPercent() {
        XCTAssertEqual(BreakShareIndicator(fraction: 0.004).level, .warning)
    }

    func testUsesCautionLevelBetweenHalfAndOnePercent() {
        XCTAssertEqual(BreakShareIndicator(fraction: 0.005).level, .caution)
        XCTAssertEqual(BreakShareIndicator(fraction: 0.009).level, .caution)
    }

    func testUsesHealthyLevelAtOnePercentOrAbove() {
        XCTAssertEqual(BreakShareIndicator(fraction: 0.01).level, .healthy)
        XCTAssertEqual(BreakShareIndicator(fraction: 0.02).level, .healthy)
    }
}
