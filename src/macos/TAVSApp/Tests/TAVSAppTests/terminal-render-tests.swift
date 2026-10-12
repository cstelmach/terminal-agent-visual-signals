import XCTest
@testable import TAVSApp

final class TerminalRenderTests: XCTestCase {
    private func fields() -> [String] {
        ["", ""] + Array(repeating: "", count: 16) + ["0", "", "", "", "0"]
    }

    private func data(_ fields: [String]) -> Data {
        Data((fields.joined(separator: "\0") + "\0").utf8)
    }

    func testFinitePayloadProducesKnownStylesAndSeparatesBackground() throws {
        var values = fields()
        values[0] = "#abcdef"; values[1] = "set"; values[2] = "#123456"
        values[17] = "#ABCDEF"; values[18] = "1"; values[19] = "current title"
        values[20] = "iterm2-set"; values[21] = "/fixture/image.png"; values[22] = "1"
        let render = try TerminalRender(data(values))
        XCTAssertEqual(render.background, "#ABCDEF")
        XCTAssertEqual(render.beforeBackground, Data("\u{1B}]4;0;rgb:12/34/56;15;rgb:AB/CD/EF\u{1B}\\".utf8))
        let image = Data("/fixture/image.png".utf8).base64EncodedString()
        XCTAssertEqual(render.afterBackground(synthetic: false), Data(("\u{1B}]0;current title\u{1B}\\"
            + "\u{1B}]1337;SetBackgroundImageFile=\(image)\u{07}\u{07}").utf8))
        XCTAssertFalse(render.afterBackground(synthetic: true).suffix(2) == Data([7, 7]))
    }

    func testStyleOnlyPayloadHasNoBackgroundAndSupportsExplicitClears() throws {
        var values = fields()
        values[1] = "reset"; values[18] = "1"; values[20] = "iterm2-clear"
        let render = try TerminalRender(data(values))
        XCTAssertNil(render.background)
        XCTAssertEqual(render.beforeBackground, Data("\u{1B}]104\u{1B}\\".utf8))
        XCTAssertEqual(render.afterBackground(synthetic: false), Data("\u{1B}]0;\u{1B}\\\u{1B}]1337;SetBackgroundImageFile=\u{07}".utf8))
        let empty = try TerminalRender(data(fields()))
        XCTAssertTrue(empty.beforeBackground.isEmpty)
        XCTAssertTrue(empty.afterBackground(synthetic: false).isEmpty)
    }

    func testRejectsMalformedOrControlBearingPayloadWithoutDiagnostics() {
        var invalid: [Data] = [Data(), data(Array(fields().dropLast())), data(fields() + ["extra"]),
                               Data(repeating: 65, count: 16_385), Data([255, 0])]
        for (index, value) in [(0, "bad"), (1, "unknown"), (2, "reset"), (18, "yes"),
                               (19, "UNREQUESTED"), (20, "unknown"), (21, "relative"), (22, "2")] {
            var values = fields(); values[index] = value; invalid.append(data(values))
        }
        for text in ["\u{1B}BODY_SENTINEL", "\nBODY_SENTINEL", "\u{07}BODY_SENTINEL"] {
            var values = fields(); values[18] = "1"; values[19] = text; invalid.append(data(values))
        }
        var missingTerminator = data(fields()); missingTerminator.removeLast(); invalid.append(missingTerminator)
        for payload in invalid {
            XCTAssertThrowsError(try TerminalRender(payload)) { error in
                XCTAssertFalse(String(describing: error).contains("BODY_SENTINEL"))
            }
        }
    }

    func testPreservesJoinedEmojiInOrdinaryTitle() throws {
        var values = fields(); values[18] = "1"; values[19] = "👩‍💻 coding"
        XCTAssertEqual(try TerminalRender(data(values)).title, "👩‍💻 coding")
    }
}
