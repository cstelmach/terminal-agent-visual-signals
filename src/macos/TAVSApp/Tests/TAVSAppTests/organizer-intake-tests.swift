import XCTest
@testable import TAVSApp

final class OrganizerIntakeTests: XCTestCase {
    func testTopLevelMetadataDecodesEscapesAndDiscardsBodyFields() throws {
        let input = Data(#"{"permission_mode":"plan","session_id":"s\"\\x","cwd":"/a\nb","transcript_path":"/a/file","hook_event_name":"UserPromptSubmit","prompt":"BODY_SENTINEL","tool_input":{"session_id":"nested"}}"#.utf8)
        let result = try OrganizerIntake.decode(input, provider: "claude")
        XCTAssertEqual(result.fields["TAVS_PERMISSION_MODE"], "plan")
        XCTAssertEqual(result.fields["TAVS_SESSION_ID"], "s\"\\x")
        XCTAssertEqual(result.fields["TAVS_CWD"], "/a\nb")
        XCTAssertEqual(result.event, "UserPromptSubmit")
        XCTAssertFalse(result.fields.values.contains { $0.contains("BODY_SENTINEL") })
    }

    func testCodexSuppliedIDAndMissingIDAreDistinct() throws {
        let supplied = try OrganizerIntake.decode(Data(#"{"type":"agent-turn-complete","thread-id":"thread","turn-id":"turn","last-assistant-message":"BODY_SENTINEL"}"#.utf8), provider: "codex")
        XCTAssertEqual(supplied.responseID, "turn")
        XCTAssertEqual(supplied.event, "agent-turn-complete")
        let missing = try OrganizerIntake.decode(Data(#"{"type":"agent-turn-complete"}"#.utf8), provider: "codex")
        XCTAssertNil(missing.responseID)
    }

    func testWrongTypesMalformedAndOversizedInputAreRejectedWithoutContentErrors() {
        for input in [Data("BODY_SENTINEL $(command)".utf8), Data(#"{"session_id":42}"#.utf8), Data(repeating: 65, count: 1_048_577)] {
            XCTAssertThrowsError(try OrganizerIntake.decode(input, provider: "claude")) { error in
                XCTAssertFalse(String(describing: error).contains("BODY_SENTINEL"))
            }
        }
    }

    func testUnknownEventCannotBecomePermissionAndNulCannotInjectFields() throws {
        let input = Data(#"{"hook_event_name":"Notification","notification_type":"unrecognized","permission_mode":"unrecognized"}"#.utf8)
        let result = try OrganizerIntake.decode(input, provider: "claude")
        XCTAssertNil(result.event)
        XCTAssertEqual(result.fields["TAVS_PERMISSION_MODE"], "default")
        XCTAssertThrowsError(try OrganizerIntake.decode(Data(#"{"cwd":"/a\u0000TAVS_ORGANIZER_INTAKE"}"#.utf8), provider: "claude"))
    }

    func testSessionAndThreadIdentifiersRejectTerminalControls() throws {
        for provider in ["claude", "codex"] {
            for id in ["a\u{07}\u{1B}[2J", "a\nb", "a\rb"] {
                let key = provider == "claude" ? "session_id" : "thread-id"
                let data = try JSONSerialization.data(withJSONObject: [key: id])
                XCTAssertThrowsError(try OrganizerIntake.decode(data, provider: provider))
            }
        }
    }

    func testResolvedProviderCommandAcceptsVersionedNativeBinaryButRejectsInterpreters() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let executable = root.appendingPathComponent("2.1.295")
        let command = root.appendingPathComponent("claude")
        try Data().write(to: executable)
        try FileManager.default.createSymbolicLink(at: command, withDestinationURL: executable)
        XCTAssertTrue(OrganizerIntake.matchesProviderExecutable(provider: "claude", path: executable.path,
                                                               commands: [command.path]))
        XCTAssertFalse(OrganizerIntake.matchesProviderExecutable(provider: "claude", path: "/usr/bin/node",
                                                                commands: [command.path, "/usr/bin/node"]))
        XCTAssertFalse(OrganizerIntake.matchesProviderExecutable(provider: "claude", path: "/unknown/2.1.295",
                                                                commands: [command.path]))
        XCTAssertTrue(OrganizerIntake.matchesProviderExecutable(provider: "codex", path: "/installed/codex",
                                                               commands: []))
    }
}
