import XCTest
@testable import TAVSApp

final class UserConfStoreTests: XCTestCase {
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("tavs-conftest-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    private func fixtureURL() -> URL {
        Bundle.module.url(forResource: "user", withExtension: "conf", subdirectory: "Fixtures")!
    }

    private func copyFixture() throws -> URL {
        let source = fixtureURL()
        let dest = tempDir.appendingPathComponent("user.conf")
        try FileManager.default.copyItem(at: source, to: dest)
        return dest
    }

    // MARK: - Round-trip byte preservation

    func testRoundTripNoChangesPreservesBytes() throws {
        let dest = try copyFixture()
        let originalData = try Data(contentsOf: dest)

        let store = try UserConfStore(url: dest)
        try store.save()

        let savedData = try Data(contentsOf: dest)
        XCTAssertEqual(originalData, savedData, "Round-trip without changes must be byte-identical")
    }

    // MARK: - Reading curated keys

    func testReadThemePreset() throws {
        let dest = try copyFixture()
        let store = try UserConfStore(url: dest)
        XCTAssertEqual(store.themePreset, "nord")
    }

    func testReadThemeMode() throws {
        let dest = try copyFixture()
        let store = try UserConfStore(url: dest)
        XCTAssertEqual(store.themeMode, "preset")
    }

    func testReadTitleMode() throws {
        let dest = try copyFixture()
        let store = try UserConfStore(url: dest)
        XCTAssertEqual(store.titleMode, "prefix-only")
    }

    func testReadFaceMode() throws {
        let dest = try copyFixture()
        let store = try UserConfStore(url: dest)
        XCTAssertEqual(store.faceMode, "compact")
    }

    func testReadCompactTheme() throws {
        let dest = try copyFixture()
        let store = try UserConfStore(url: dest)
        XCTAssertEqual(store.compactTheme, "squares")
    }

    func testReadIdentityMode() throws {
        let dest = try copyFixture()
        let store = try UserConfStore(url: dest)
        XCTAssertEqual(store.identityMode, "dual")
    }

    func testReadDirIconType() throws {
        let dest = try copyFixture()
        let store = try UserConfStore(url: dest)
        XCTAssertEqual(store.dirIconType, "flags")
    }

    func testReadStylishBackgrounds() throws {
        let dest = try copyFixture()
        let store = try UserConfStore(url: dest)
        XCTAssertEqual(store.stylishBackgrounds, false)
    }

    func testReadLightDarkSwitching() throws {
        let dest = try copyFixture()
        let store = try UserConfStore(url: dest)
        XCTAssertEqual(store.lightDarkSwitching, true)
    }

    func testPauseBgAccessorsRoundTrip() throws {
        let dest = try copyFixture()
        let store = try UserConfStore(url: dest)

        // Keys absent from the baseline fixture → nil, caller falls back to
        // the documented defaults.
        XCTAssertNil(store.pauseBgDark)
        XCTAssertNil(store.pauseBgLight)
        XCTAssertEqual(UserConfStore.defaultPauseBgDark, "#3A3A3A")
        XCTAssertEqual(UserConfStore.defaultPauseBgLight, "#D0D0D0")

        store.pauseBgDark = "#112233"
        store.pauseBgLight = "#EEEEEE"
        try store.save()

        let reloaded = try UserConfStore(url: dest)
        XCTAssertEqual(reloaded.pauseBgDark, "#112233")
        XCTAssertEqual(reloaded.pauseBgLight, "#EEEEEE")
    }

    func testPauseFgAccessorsRoundTrip() throws {
        let dest = try copyFixture()
        let store = try UserConfStore(url: dest)

        XCTAssertNil(store.pauseFgDark)
        XCTAssertNil(store.pauseFgLight)
        XCTAssertEqual(UserConfStore.defaultPauseFgDark, "#F2F2F2")
        XCTAssertEqual(UserConfStore.defaultPauseFgLight, "#202020")

        store.pauseFgDark = "#F2F2F2"
        store.pauseFgLight = "#202020"
        try store.save()

        let reloaded = try UserConfStore(url: dest)
        XCTAssertEqual(reloaded.pauseFgDark, "#F2F2F2")
        XCTAssertEqual(reloaded.pauseFgLight, "#202020")
    }

    func testMissingPauseForegroundKeysAreNotPersistedOnUnrelatedSave() throws {
        let dest = tempDir.appendingPathComponent("no-foreground.conf")
        try """
        # minimal config
        THEME_PRESET="nord"
        TAVS_PAUSE_BG_DARK="#111111"
        """
        .write(to: dest, atomically: true, encoding: .utf8)

        let store = try UserConfStore(url: dest)
        XCTAssertNil(store.pauseFgDark)
        XCTAssertNil(store.pauseFgLight)

        store.pauseBgDark = "#222222"
        try store.save()

        let content = try String(contentsOf: dest, encoding: .utf8)
        XCTAssertFalse(content.contains("TAVS_PAUSE_FG_DARK"))
        XCTAssertFalse(content.contains("TAVS_PAUSE_FG_LIGHT"))
    }

    func testDuplicateKeysReadLastMatch() throws {
        let dest = tempDir.appendingPathComponent("duplicates.conf")
        try """
        THEME_PRESET="nord"
        THEME_PRESET="dracula"
        TAVS_PAUSE_FG_LIGHT="#111111"
        TAVS_PAUSE_FG_LIGHT="#222222"
        """
        .write(to: dest, atomically: true, encoding: .utf8)

        let store = try UserConfStore(url: dest)

        XCTAssertEqual(store.themePreset, "dracula")
        XCTAssertEqual(store.pauseFgLight, "#222222")
    }

    func testSettingDuplicateKeyReplacesLastMatchOnly() throws {
        let dest = tempDir.appendingPathComponent("duplicate-save.conf")
        try """
        # keep this comment
        TAVS_PAUSE_FG_DARK="#111111"

        UNMANAGED_SHELL_ARRAY=("a" "b")
        TAVS_PAUSE_FG_DARK="#222222"
        """
        .write(to: dest, atomically: true, encoding: .utf8)

        let store = try UserConfStore(url: dest)
        store.pauseFgDark = "#333333"
        try store.save()

        let content = try String(contentsOf: dest, encoding: .utf8)
        let lines = content.components(separatedBy: "\n")

        XCTAssertTrue(content.contains("# keep this comment"))
        XCTAssertTrue(content.contains("\n\n"))
        XCTAssertTrue(content.contains("UNMANAGED_SHELL_ARRAY=(\"a\" \"b\")"))
        XCTAssertEqual(lines.filter { $0 == "TAVS_PAUSE_FG_DARK=\"#111111\"" }.count, 1)
        XCTAssertEqual(lines.filter { $0 == "TAVS_PAUSE_FG_DARK=\"#333333\"" }.count, 1)
        XCTAssertFalse(content.contains("TAVS_PAUSE_FG_DARK=\"#222222\""))
    }

    // MARK: - Mutate one key, diff shows exactly that line

    func testMutateOneKeyChangesOnlyThatLine() throws {
        let dest = try copyFixture()
        let originalLines = try String(contentsOf: dest, encoding: .utf8)
            .components(separatedBy: "\n")

        let store = try UserConfStore(url: dest)
        store.themePreset = "dracula"
        try store.save()

        let savedLines = try String(contentsOf: dest, encoding: .utf8)
            .components(separatedBy: "\n")

        XCTAssertEqual(originalLines.count, savedLines.count, "Line count must not change")

        var changedLines = 0
        for (i, (orig, saved)) in zip(originalLines, savedLines).enumerated() {
            if orig != saved {
                changedLines += 1
                XCTAssertTrue(saved.contains("THEME_PRESET=\"dracula\""),
                              "Changed line \(i) should contain new value, got: \(saved)")
            }
        }
        XCTAssertEqual(changedLines, 1, "Exactly one line should differ")
    }

    // MARK: - Comments and unknown keys preserved

    func testCommentsPreserved() throws {
        let dest = try copyFixture()
        let store = try UserConfStore(url: dest)
        store.faceMode = "standard"
        try store.save()

        let content = try String(contentsOf: dest, encoding: .utf8)
        XCTAssertTrue(content.contains("# TAVS User Configuration"))
        XCTAssertTrue(content.contains("# Theme settings"))
        XCTAssertTrue(content.contains("# Some unknown key from wizard"))
    }

    func testUnknownKeysPreserved() throws {
        let dest = try copyFixture()
        let store = try UserConfStore(url: dest)
        store.identityMode = "single"
        try store.save()

        let content = try String(contentsOf: dest, encoding: .utf8)
        XCTAssertTrue(content.contains("TAVS_SPINNER_STYLE=\"random\""))
        XCTAssertTrue(content.contains("TAVS_SPINNER_EYE_MODE=\"mirror\""))
        XCTAssertTrue(content.contains("CLAUDE_DARK_BASE=\"#1e1e2e\""))
        XCTAssertTrue(content.contains("GEMINI_FACES_PROCESSING="))
    }

    func testBlankLinesPreserved() throws {
        let dest = try copyFixture()
        let originalContent = try String(contentsOf: dest, encoding: .utf8)
        let originalBlanks = originalContent.components(separatedBy: "\n")
            .filter { $0.trimmingCharacters(in: .whitespaces).isEmpty }

        let store = try UserConfStore(url: dest)
        try store.save()

        let savedContent = try String(contentsOf: dest, encoding: .utf8)
        let savedBlanks = savedContent.components(separatedBy: "\n")
            .filter { $0.trimmingCharacters(in: .whitespaces).isEmpty }

        XCTAssertEqual(originalBlanks.count, savedBlanks.count)
    }

    // MARK: - Multiple mutations

    func testMutateMultipleKeys() throws {
        let dest = try copyFixture()
        let store = try UserConfStore(url: dest)
        store.themePreset = "tokyo-night"
        store.titleMode = "full"
        store.stylishBackgrounds = true
        try store.save()

        let reloaded = try UserConfStore(url: dest)
        XCTAssertEqual(reloaded.themePreset, "tokyo-night")
        XCTAssertEqual(reloaded.titleMode, "full")
        XCTAssertEqual(reloaded.stylishBackgrounds, true)
        XCTAssertEqual(reloaded.faceMode, "compact") // unchanged
    }

    // MARK: - Missing key adds it at end

    func testMissingKeyAppendsOnSave() throws {
        let dest = tempDir.appendingPathComponent("minimal.conf")
        try "# minimal config\nTHEME_PRESET=\"nord\"\n"
            .write(to: dest, atomically: true, encoding: .utf8)

        let store = try UserConfStore(url: dest)
        XCTAssertEqual(store.themePreset, "nord")
        XCTAssertNil(store.titleMode)

        store.titleMode = "full"
        try store.save()

        let content = try String(contentsOf: dest, encoding: .utf8)
        XCTAssertTrue(content.contains("TAVS_TITLE_MODE=\"full\""))
        XCTAssertTrue(content.contains("# minimal config"))
    }

    // MARK: - Load nonexistent

    func testLoadNonexistentReturnsEmpty() throws {
        let path = tempDir.appendingPathComponent("nonexistent.conf")
        let store = try UserConfStore(url: path)
        XCTAssertNil(store.themePreset)
    }

    // MARK: - Bool accessors

    func testBoolSetToTrue() throws {
        let dest = try copyFixture()
        let store = try UserConfStore(url: dest)
        store.stylishBackgrounds = true
        try store.save()

        let content = try String(contentsOf: dest, encoding: .utf8)
        XCTAssertTrue(content.contains("ENABLE_STYLISH_BACKGROUNDS=\"true\""))
    }

    func testBoolSetToFalse() throws {
        let dest = try copyFixture()
        let store = try UserConfStore(url: dest)
        store.lightDarkSwitching = false
        try store.save()

        let content = try String(contentsOf: dest, encoding: .utf8)
        XCTAssertTrue(content.contains("ENABLE_LIGHT_DARK_SWITCHING=\"false\""))
    }

    // MARK: - Phase 5: Five-key change = five line diff

    func testFiveKeyChangeFiveLineDiff() throws {
        let dest = try copyFixture()
        let originalLines = try String(contentsOf: dest, encoding: .utf8)
            .components(separatedBy: "\n")

        let store = try UserConfStore(url: dest)
        store.themePreset = "dracula"
        store.titleMode = "full"
        store.faceMode = "standard"
        store.identityMode = "single"
        store.stylishBackgrounds = true
        try store.save()

        let savedContent = try String(contentsOf: dest, encoding: .utf8)
        let savedLines = savedContent.components(separatedBy: "\n")
        XCTAssertEqual(originalLines.count, savedLines.count, "Line count must not change")

        var changedCount = 0
        for (orig, saved) in zip(originalLines, savedLines) {
            if orig != saved { changedCount += 1 }
        }
        XCTAssertEqual(changedCount, 5, "Exactly 5 lines should differ after 5 key changes")

        XCTAssertTrue(savedContent.contains("# TAVS User Configuration"))
        XCTAssertTrue(savedContent.contains("# Some unknown key from wizard"))
        XCTAssertTrue(savedContent.contains("TAVS_SPINNER_STYLE=\"random\""))
        XCTAssertTrue(savedContent.contains("CLAUDE_DARK_BASE=\"#1e1e2e\""))
    }

    // MARK: - Phase 5: Reload-and-save preserves external changes

    func testReloadBeforeSavePreservesExternalEdits() throws {
        let dest = try copyFixture()

        let store1 = try UserConfStore(url: dest)
        store1.themePreset = "dracula"
        try store1.save()

        let store2 = try UserConfStore(url: dest)
        XCTAssertEqual(store2.themePreset, "dracula")
        store2.titleMode = "full"
        try store2.save()

        let final = try UserConfStore(url: dest)
        XCTAssertEqual(final.themePreset, "dracula")
        XCTAssertEqual(final.titleMode, "full")
        XCTAssertEqual(final.faceMode, "compact")
    }
}
