import XCTest
@testable import TAVSApp

final class PreferencesPauseVisualPreferenceColorsTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("tavs-prefs-colors-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testResolvedColorsUseRuntimePauseVisualFallbacks() throws {
        let url = tempDir.appendingPathComponent("user.conf")
        try """
        TAVS_PAUSE_BG_DARK="not-a-color"
        TAVS_PAUSE_FG_DARK="#101010"
        TAVS_PAUSE_BG_LIGHT="#CCCCCC"
        TAVS_PAUSE_FG_LIGHT="bad"
        """
        .write(to: url, atomically: true, encoding: .utf8)

        let store = try UserConfStore(url: url)
        let colors = PauseVisualPreferenceColors.resolved(from: store)

        XCTAssertEqual(colors.darkBackground, UserConfStore.defaultPauseBgDark)
        XCTAssertEqual(colors.darkForeground, "#101010")
        XCTAssertEqual(colors.lightBackground, "#CCCCCC")
        XCTAssertEqual(colors.lightForeground, UserConfStore.defaultPauseFgLight)
    }

    func testUnchangedDisplayedColorsPreserveMalformedRawPauseLines() throws {
        let url = tempDir.appendingPathComponent("user.conf")
        try """
        THEME_PRESET="nord"
        TAVS_PAUSE_BG_DARK="not-a-color"
        TAVS_PAUSE_FG_DARK="also-bad"
        TAVS_PAUSE_BG_LIGHT="#EEEEEE"
        TAVS_PAUSE_FG_LIGHT="nope"
        """
        .write(to: url, atomically: true, encoding: .utf8)

        let initialStore = try UserConfStore(url: url)
        let initialColors = PauseVisualPreferenceColors.resolved(from: initialStore)

        let saveStore = try UserConfStore(url: url)
        saveStore.themePreset = "dracula"
        XCTAssertFalse(initialColors.applyChanges(since: initialColors, to: saveStore))
        try saveStore.save()

        let saved = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(saved.contains("THEME_PRESET=\"dracula\""))
        XCTAssertTrue(saved.contains("TAVS_PAUSE_BG_DARK=\"not-a-color\""))
        XCTAssertTrue(saved.contains("TAVS_PAUSE_FG_DARK=\"also-bad\""))
        XCTAssertTrue(saved.contains("TAVS_PAUSE_FG_LIGHT=\"nope\""))
    }

    func testChangedForegroundPersistsOnlyThatForegroundKey() throws {
        let url = tempDir.appendingPathComponent("user.conf")
        try """
        TAVS_PAUSE_BG_DARK="#333333"
        TAVS_PAUSE_BG_LIGHT="#DDDDDD"
        """
        .write(to: url, atomically: true, encoding: .utf8)

        let initialStore = try UserConfStore(url: url)
        let initialColors = PauseVisualPreferenceColors.resolved(from: initialStore)
        var changedColors = initialColors
        changedColors.darkForeground = "#ABCDEF"

        let saveStore = try UserConfStore(url: url)
        XCTAssertTrue(changedColors.applyChanges(since: initialColors, to: saveStore))
        try saveStore.save()

        let saved = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(saved.contains("TAVS_PAUSE_FG_DARK=\"#ABCDEF\""))
        XCTAssertFalse(saved.contains("TAVS_PAUSE_FG_LIGHT"))
        let pauseBackgroundCount = saved.components(separatedBy: "\n")
            .filter { $0.contains("TAVS_PAUSE_BG_") }
            .count
        XCTAssertEqual(pauseBackgroundCount, 2)
    }
}
