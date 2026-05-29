import XCTest
@testable import TAVSApp

final class PauseVisualTests: XCTestCase {
    func testValidColorsNormalizeToUppercaseHashRGB() {
        let visual = PauseVisual(
            backgroundColor: "#aabbcc",
            foregroundColor: "#0011ef",
            defaultBackgroundColor: UserConfStore.defaultPauseBgDark
        )

        XCTAssertEqual(visual.backgroundColor, "#AABBCC")
        XCTAssertEqual(visual.foregroundColor, "#0011EF")
    }

    func testMalformedBackgroundFallsBackToProvidedDefault() {
        let visual = PauseVisual(
            backgroundColor: "112233",
            foregroundColor: "#ABCDEF",
            defaultBackgroundColor: UserConfStore.defaultPauseBgLight
        )

        XCTAssertEqual(visual.backgroundColor, UserConfStore.defaultPauseBgLight)
        XCTAssertEqual(visual.foregroundColor, "#ABCDEF")
    }

    func testAbsentForegroundDerivesSoftReadableForDarkBackground() {
        let visual = PauseVisual(
            backgroundColor: UserConfStore.defaultPauseBgDark,
            foregroundColor: nil,
            defaultBackgroundColor: UserConfStore.defaultPauseBgDark
        )

        XCTAssertEqual(visual.backgroundColor, UserConfStore.defaultPauseBgDark)
        XCTAssertEqual(visual.foregroundColor, UserConfStore.defaultPauseFgDark)
    }

    func testMalformedForegroundDerivesSoftReadableForLightBackground() {
        let visual = PauseVisual(
            backgroundColor: UserConfStore.defaultPauseBgLight,
            foregroundColor: "not-a-color",
            defaultBackgroundColor: UserConfStore.defaultPauseBgLight
        )

        XCTAssertEqual(visual.backgroundColor, UserConfStore.defaultPauseBgLight)
        XCTAssertEqual(visual.foregroundColor, UserConfStore.defaultPauseFgLight)
    }

    func testCustomBackgroundUsesHighestContrastWhenSoftCandidatesFail() {
        let visual = PauseVisual(
            backgroundColor: "#777777",
            foregroundColor: nil,
            defaultBackgroundColor: UserConfStore.defaultPauseBgDark
        )

        XCTAssertEqual(visual.backgroundColor, "#777777")
        XCTAssertEqual(visual.foregroundColor, "#000000")
    }

    func testMixedMalformedValuesUseFallbackBackgroundThenForeground() {
        let visual = PauseVisual(
            backgroundColor: "#GGGGGG",
            foregroundColor: "bad",
            defaultBackgroundColor: UserConfStore.defaultPauseBgLight
        )

        XCTAssertEqual(visual.backgroundColor, UserConfStore.defaultPauseBgLight)
        XCTAssertEqual(visual.foregroundColor, UserConfStore.defaultPauseFgLight)
    }

    func testValidLowContrastForegroundWins() {
        let visual = PauseVisual(
            backgroundColor: "#000000",
            foregroundColor: "#010101",
            defaultBackgroundColor: UserConfStore.defaultPauseBgDark
        )

        XCTAssertEqual(visual.backgroundColor, "#000000")
        XCTAssertEqual(visual.foregroundColor, "#010101")
    }
}
