import XCTest
@testable import TAVSApp

final class ChallengeVerifierTests: XCTestCase {
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("tavs-challenge-test-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    private func writeConf(_ contents: String) -> URL {
        let url = tempDir.appendingPathComponent("challenge.conf")
        try! contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Hash spec (vectors mirrored in tests/unit/challenge.bats)

    func testPasswordHashKnownVector() {
        // printf 'aabbsecret' | shasum -a 256
        XCTAssertEqual(
            ChallengeVerifier.passwordHash(saltHex: "aabb", password: "secret"),
            "fd102f9d583ab679f454a0b4d3134968174aa46241537030fad12163492ba7cf"
        )
    }

    func testPasswordHashIsLowercaseHex64() {
        let hash = ChallengeVerifier.passwordHash(saltHex: "00", password: "x")
        XCTAssertEqual(hash.count, 64)
        XCTAssertEqual(hash, hash.lowercased())
    }

    func testVerifyPasswordRoundTrip() {
        let salt = "00112233445566778899aabbccddeeff"
        let config = ChallengeConfig(
            type: .password, saltHex: salt,
            hashHex: ChallengeVerifier.passwordHash(saltHex: salt, password: "hunter2"),
            sentencesFile: ""
        )
        XCTAssertTrue(ChallengeVerifier.verifyPassword("hunter2", config: config))
        XCTAssertFalse(ChallengeVerifier.verifyPassword("hunter3", config: config))
        XCTAssertFalse(ChallengeVerifier.verifyPassword("", config: config))
    }

    // MARK: - Puzzle transform (vectors mirrored in tests/unit/challenge.bats)

    func testPuzzleTransformVector() {
        XCTAssertEqual(
            ChallengeVerifier.puzzleTransform("the quick brown fox"),
            "het uickq rownb oxf"
        )
    }

    func testPuzzleTransformSingleLetterWords() {
        XCTAssertEqual(ChallengeVerifier.puzzleTransform("a calm mind"), "a almc indm")
    }

    func testVerifyPuzzleTrimsTrailingWhitespaceOnly() {
        XCTAssertTrue(ChallengeVerifier.verifyPuzzle(
            answer: "het uickq rownb oxf  ", sentence: "the quick brown fox"))
        XCTAssertFalse(ChallengeVerifier.verifyPuzzle(
            answer: "  het uickq rownb oxf", sentence: "the quick brown fox"))
        XCTAssertFalse(ChallengeVerifier.verifyPuzzle(
            answer: "the quick brown fox", sentence: "the quick brown fox"))
    }

    // MARK: - Config loading (mirrors challenge.sh degradation rules)

    func testLoadConfigPassword() {
        let url = writeConf("""
        CHALLENGE_TYPE="password"
        PASSWORD_SALT_HEX="aabb"
        PASSWORD_HASH_HEX="cafe"
        SCHEMA_VERSION="1"
        """)
        let config = ChallengeVerifier.loadConfig(at: url)
        XCTAssertEqual(config.type, .password)
        XCTAssertEqual(config.saltHex, "aabb")
        XCTAssertEqual(config.hashHex, "cafe")
    }

    func testLoadConfigAbsentFileFallsBackToPuzzle() {
        let config = ChallengeVerifier.loadConfig(at: tempDir.appendingPathComponent("nope"))
        XCTAssertEqual(config.type, .puzzle)
    }

    func testLoadConfigPasswordWithoutHashDegradesToPuzzle() {
        let url = writeConf("CHALLENGE_TYPE=\"password\"\nSCHEMA_VERSION=\"1\"\n")
        XCTAssertEqual(ChallengeVerifier.loadConfig(at: url).type, .puzzle)
    }

    func testLoadConfigUnknownTypeDegradesToPuzzle() {
        let url = writeConf("CHALLENGE_TYPE=\"retina-scan\"\nSCHEMA_VERSION=\"1\"\n")
        XCTAssertEqual(ChallengeVerifier.loadConfig(at: url).type, .puzzle)
    }

    // MARK: - Sentences

    func testRandomSentenceUsesOverrideFile() {
        let pool = tempDir.appendingPathComponent("pool.txt")
        try! "only one sentence here\n".write(to: pool, atomically: true, encoding: .utf8)
        let config = ChallengeConfig(type: .puzzle, saltHex: "", hashHex: "", sentencesFile: pool.path)
        XCTAssertEqual(ChallengeVerifier.randomSentence(config: config), "only one sentence here")
    }

    func testDefaultPoolIsWellFormed() {
        XCTAssertGreaterThanOrEqual(DefaultPuzzleSentences.all.count, 30)
        for sentence in DefaultPuzzleSentences.all {
            XCTAssertNil(sentence.rangeOfCharacter(from: CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz ").inverted),
                         "Pool sentences must be lowercase words + spaces: '\(sentence)'")
            XCTAssertFalse(sentence.contains("  "))
        }
    }
}
