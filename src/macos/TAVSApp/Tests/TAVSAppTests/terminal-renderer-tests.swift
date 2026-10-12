import XCTest
@testable import TAVSApp

final class TerminalRendererTests: XCTestCase {
    func testFocusChangesNeutralDarkLightAndExtremeBackgroundsWithinBounds() throws {
        for (background, foreground) in [("#171717", "#EEEEEE"), ("#FAFAFA", "#161616"),
                                        ("#000000", "#FFFFFF"), ("#FFFFFF", "#000000")] {
            let colors = try XCTUnwrap(TerminalRenderer.Colors(background: background, foreground: foreground))
            let dim = try XCTUnwrap(TerminalRenderer.focusBackground(ordinary: nil, colors: colors))
            let a = PauseVisual.rgbComponents(background), b = PauseVisual.rgbComponents(dim)
            XCTAssertEqual(PauseVisual.normalizedHexColor(dim), dim)
            XCTAssertGreaterThanOrEqual(abs(a.red - b.red) + abs(a.green - b.green) + abs(a.blue - b.blue), 24.0 / 255)
            XCTAssertLessThanOrEqual(abs(PauseVisual.relativeLuminance(background) - PauseVisual.relativeLuminance(dim)), 0.08)
            XCTAssertGreaterThanOrEqual(PauseVisual.contrastRatio(dim, foreground), 4.5)
        }
    }

    func testFocusReducesChromaAndUsesCurrentIntentRatherThanConfiguredDefault() throws {
        let colors = try XCTUnwrap(TerminalRenderer.Colors(background: "#171717", foreground: "#FFFFFF"))
        for ordinary in ["#FF0000", "#00FF00", "#0000FF", "#FFFF00"] {
            let dim = try XCTUnwrap(TerminalRenderer.focusBackground(ordinary: ordinary, colors: colors))
            let rgb = PauseVisual.rgbComponents(dim)
            XCTAssertLessThan(max(rgb.red, rgb.green, rgb.blue) - min(rgb.red, rgb.green, rgb.blue), 1)
            XCTAssertGreaterThanOrEqual(PauseVisual.contrastRatio(dim, colors.foreground),
                min(4.5, PauseVisual.contrastRatio(ordinary, colors.foreground)))
            XCTAssertNotEqual(dim, TerminalRenderer.focusBackground(ordinary: nil, colors: colors))
        }
        XCTAssertEqual(TerminalRenderer.focusBackground(ordinary: "reset", colors: colors),
                       TerminalRenderer.focusBackground(ordinary: nil, colors: colors))
    }

    func testFocusDoesNotInventSafeChangesForInvalidOrLowContrastExtremes() throws {
        for colors in [TerminalRenderer.Colors(background: "#000000", foreground: "#747474"),
                       TerminalRenderer.Colors(background: "#FFFFFF", foreground: "#929292")] {
            XCTAssertNil(TerminalRenderer.focusBackground(ordinary: nil, colors: try XCTUnwrap(colors)))
        }
        let colors = try XCTUnwrap(TerminalRenderer.Colors(background: "#171717", foreground: "#EEEEEE"))
        XCTAssertNil(TerminalRenderer.focusBackground(ordinary: "invalid", colors: colors))
    }

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

    func testCanonicalConfigurationColorsAndUnresolvedDualTheme() throws {
        let good = Data("theme =\nforeground = #EeEeEe\nbackground = #171717\ncommand = ignored=also\n".utf8)
        XCTAssertEqual(try TerminalRenderer.parseConfiguration(good),
            TerminalRenderer.Colors(background: "#171717", foreground: "#EEEEEE"))
        for bad in ["background = red\nforeground = #EEEEEE\ntheme =\n",
                    "background = #171717\nforeground = #EEEEEE\nbackground = #000000\ntheme =\n",
                    "background = #171717\nforeground = #EEEEEE\ntheme = light:A,dark:B\n",
                    "background = #171717\nforeground = #EEEEEE\n"] {
            XCTAssertThrowsError(try TerminalRenderer.parseConfiguration(Data(bad.utf8)))
        }
        XCTAssertThrowsError(try TerminalRenderer.parseConfiguration(Data([0xFF])))
    }

    func testMissingConfigurationUsesExplicitDefaultsWithoutDefaultFileLoading() throws {
        let directory = URL(fileURLWithPath: try XCTUnwrap(ProcessInfo.processInfo.environment["TAVS_TEST_ROOT"]))
            .appendingPathComponent("config-\(UUID().uuidString)")
        let runner = MockProcessRunner(), executable = URL(fileURLWithPath: "/fixture/Ghostty")
        runner.boundedResults = [.success(Data("background = #171717\nforeground = #EEEEEE\ntheme =\n".utf8))]
        _ = try TerminalRenderer.configuredColors(executable: executable,
            configurationFiles: [directory.appendingPathComponent("config")], runner: runner)
        XCTAssertEqual(runner.runCallLog.count, 1)
        XCTAssertEqual(runner.runCallLog.first?.1, ["+show-config", "--default", "--no-pager"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    func testConfiguredQueryValidatesBeforeParsingAndPropagatesFailure() throws {
        let directory = URL(fileURLWithPath: try XCTUnwrap(ProcessInfo.processInfo.environment["TAVS_TEST_ROOT"]))
            .appendingPathComponent("config-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("config")
        try Data("existing user config".utf8).write(to: file)
        let original = try Data(contentsOf: file), runner = MockProcessRunner()
        runner.boundedResults = [.failure(ProcessRunnerError.processExited(1))]
        XCTAssertThrowsError(try TerminalRenderer.configuredColors(executable: URL(fileURLWithPath: "/fixture/Ghostty"),
            configurationFiles: [file], runner: runner))
        XCTAssertEqual(runner.runCallLog.first?.1, ["+validate-config"])
        XCTAssertEqual(runner.runCallLog.count, 1)
        XCTAssertEqual(try Data(contentsOf: file), original)
        runner.boundedResults = [.success(Data()), .success(Data("background = #171717\nforeground = #EEEEEE\ntheme = Single\n".utf8))]
        _ = try TerminalRenderer.configuredColors(executable: URL(fileURLWithPath: "/fixture/Ghostty"),
            configurationFiles: [file], runner: runner)
        XCTAssertEqual(runner.runCallLog.last?.1, ["+show-config", "--changes-only=false", "--no-pager"])
        XCTAssertEqual(try Data(contentsOf: file), original)
    }
}
