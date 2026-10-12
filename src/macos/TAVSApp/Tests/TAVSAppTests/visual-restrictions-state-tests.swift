import XCTest
import Darwin
@testable import TAVSApp

final class VisualRestrictionsStateTests: XCTestCase {
    private var directory: URL!
    private var url: URL { directory.appendingPathComponent("visual-restrictions.state") }

    override func setUpWithError() throws {
        let root = try XCTUnwrap(ProcessInfo.processInfo.environment["TAVS_TEST_ROOT"])
        directory = URL(fileURLWithPath: root).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }

    func testSharedClassificationFixtures() throws {
        struct Fixture: Decodable { let cases: [Entry] }
        struct Entry: Decodable { let name: String; let text: String?; let expected: String }
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { root.deleteLastPathComponent() }
        let fixture = root.appendingPathComponent("tests/fixtures/visual-restrictions-state.json")
        let cases = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: fixture)).cases
        for entry in cases {
            let file = directory.appendingPathComponent(entry.name)
            if let text = entry.text { try Data(text.utf8).write(to: file) }
            XCTAssertEqual(VisualRestrictionsStateStore(url: file).read().rawValue, entry.expected, entry.name)
        }
        let home = try XCTUnwrap(ProcessInfo.processInfo.environment["HOME"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: home + "/.tavs/MUST_NOT_RUN"))
    }

    func testPersistenceAndAtomicWriterFormat() throws {
        let store = VisualRestrictionsStateStore(url: url)
        XCTAssertEqual(store.read(), .active)
        try store.write(suspended: true)
        XCTAssertEqual(VisualRestrictionsStateStore(url: url).read(), .suspended)
        XCTAssertEqual(try String(contentsOf: url), "SCHEMA_VERSION=\"1\"\nSUSPENDED=\"true\"\n")
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int, 0o600)
        try store.write(suspended: false)
        XCTAssertEqual(VisualRestrictionsStateStore(url: url).read(), .active)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), [url.lastPathComponent])
    }

    func testSpecialAndUnreadableFilesDisableRestrictionsWithoutBlocking() throws {
        let link = directory.appendingPathComponent("link")
        try Data("SCHEMA_VERSION=\"1\"\nSUSPENDED=\"false\"\n".utf8).write(to: url)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: url)
        XCTAssertEqual(VisualRestrictionsStateStore(url: link).read(), .unavailable)
        XCTAssertThrowsError(try VisualRestrictionsStateStore(url: link).write(suspended: false))
        let fifo = directory.appendingPathComponent("fifo")
        XCTAssertEqual(mkfifo(fifo.path, 0o600), 0)
        XCTAssertEqual(VisualRestrictionsStateStore(url: fifo).read(), .unavailable)
        XCTAssertThrowsError(try VisualRestrictionsStateStore(url: fifo).write(suspended: false))
        XCTAssertEqual(VisualRestrictionsStateStore(url: directory).read(), .unavailable)
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: url.path)
        XCTAssertEqual(VisualRestrictionsStateStore(url: url).read(), .unavailable)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    func testInvalidExistingRegularMarkerCanBeExplicitlyRepaired() throws {
        try Data("not data".utf8).write(to: url)
        let store = VisualRestrictionsStateStore(url: url)
        XCTAssertTrue(store.read().disablesRestrictions)
        try store.write(suspended: false)
        XCTAssertFalse(store.read().disablesRestrictions)
        XCTAssertEqual(store.read(), .active)
    }

    func testInaccessibleParentIsNotMisclassifiedAsMissing() throws {
        let parent = directory.appendingPathComponent("inaccessible")
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let marker = parent.appendingPathComponent("state")
        try VisualRestrictionsStateStore(url: marker).write(suspended: true)
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: parent.path)
        let status = VisualRestrictionsStateStore(url: marker).read()
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: parent.path)
        XCTAssertEqual(status, .unavailable)
    }

    func testInvalidParentsAndAccessibleMissingDirectories() throws {
        let link = directory.appendingPathComponent("parent-link")
        let missing = directory.appendingPathComponent("missing")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: missing)
        XCTAssertEqual(VisualRestrictionsStateStore(url: link.appendingPathComponent("state")).read(), .unavailable)
        let file = directory.appendingPathComponent("parent-file")
        try Data().write(to: file)
        XCTAssertEqual(VisualRestrictionsStateStore(url: file.appendingPathComponent("state")).read(), .unavailable)
        XCTAssertEqual(VisualRestrictionsStateStore(url: missing.appendingPathComponent("nested/state")).read(), .active)
    }
}
