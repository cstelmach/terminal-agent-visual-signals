import XCTest
@testable import TAVSApp

final class TerminalRendererTests: XCTestCase {
    func testDarkAndLightPreviewTintPreservesConfiguredTextContrast() throws {
        for (background, foreground) in [("#171717", "#EEEEEE"), ("#FAFAFA", "#161616")] {
            let colors = try XCTUnwrap(TerminalRenderer.Colors(background: background, foreground: foreground))
            let preview = try XCTUnwrap(TerminalRenderer.previewBackground(ordinary: nil, colors: colors))
            XCTAssertNotEqual(preview, background)
            XCTAssertEqual(PauseVisual.normalizedHexColor(preview), preview)
            XCTAssertGreaterThanOrEqual(PauseVisual.contrastRatio(preview, foreground), 4.5)
        }
    }

    func testCurrentIntentGuidesTintAndResetUsesConfiguredBackground() throws {
        let colors = try XCTUnwrap(TerminalRenderer.Colors(background: "#171717", foreground: "#FFFFFF"))
        let ordinary = try XCTUnwrap(TerminalRenderer.previewBackground(ordinary: "#123456", colors: colors))
        XCTAssertNotEqual(ordinary, TerminalRenderer.previewBackground(ordinary: nil, colors: colors))
        XCTAssertEqual(TerminalRenderer.previewBackground(ordinary: "reset", colors: colors),
                       TerminalRenderer.previewBackground(ordinary: nil, colors: colors))
        XCTAssertGreaterThanOrEqual(PauseVisual.contrastRatio(ordinary, colors.foreground), 4.5)
    }

    func testUnsafeTintIsUnavailableRatherThanWorseningLowBaseline() throws {
        let colors = try XCTUnwrap(TerminalRenderer.Colors(background: "#FFFFFF", foreground: "#777777"))
        XCTAssertLessThan(PauseVisual.contrastRatio(colors.background, colors.foreground), 4.5)
        XCTAssertNil(TerminalRenderer.previewBackground(ordinary: nil, colors: colors))
    }

    func testInvalidConfiguredColorsOrIntentCannotInventAColor() throws {
        XCTAssertNil(TerminalRenderer.Colors(background: "invalid", foreground: "#FFFFFF"))
        XCTAssertNil(TerminalRenderer.Colors(background: "#123456", foreground: "invalid"))
        let colors = try XCTUnwrap(TerminalRenderer.Colors(background: "#123456", foreground: "#FFFFFF"))
        XCTAssertNil(TerminalRenderer.previewBackground(ordinary: "invalid", colors: colors))
        XCTAssertEqual(PauseVisual.contrastRatio("#000000", "#FFFFFF"), 21, accuracy: 0.0001)
    }
}
