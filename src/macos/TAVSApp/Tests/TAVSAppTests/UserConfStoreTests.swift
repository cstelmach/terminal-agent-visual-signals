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
}
