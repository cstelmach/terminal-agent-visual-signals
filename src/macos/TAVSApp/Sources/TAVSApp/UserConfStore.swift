import Foundation

final class UserConfStore {
    private let url: URL
    private var lines: [ConfLine]

    private static let curatedKeys: Set<String> = [
        "THEME_PRESET", "THEME_MODE",
        "TAVS_TITLE_MODE", "TAVS_FACE_MODE", "TAVS_COMPACT_THEME",
        "TAVS_IDENTITY_MODE", "TAVS_DIR_ICON_TYPE",
        "ENABLE_STYLISH_BACKGROUNDS", "ENABLE_LIGHT_DARK_SWITCHING",
        "TAVS_PAUSE_BG_DARK", "TAVS_PAUSE_BG_LIGHT",
        "TAVS_PAUSE_FG_DARK", "TAVS_PAUSE_FG_LIGHT",
    ]

    // Defaults if keys absent: mid-grey for dark appearance preserves the
    // pre-configurable behavior; a lighter grey for light appearance keeps
    // the "paused ≠ active" contrast without reading as an error state.
    static let defaultPauseBgDark = "#3A3A3A"
    static let defaultPauseBgLight = "#D0D0D0"
    static let defaultPauseFgDark = "#F2F2F2"
    static let defaultPauseFgLight = "#202020"

    init(url: URL) throws {
        self.url = url
        if FileManager.default.fileExists(atPath: url.path) {
            let content = try String(contentsOf: url, encoding: .utf8)
            self.lines = Self.parse(content)
        } else {
            self.lines = []
        }
    }

    // MARK: - Curated key accessors

    var themePreset: String? {
        get { value(for: "THEME_PRESET") }
        set { setValue(newValue, for: "THEME_PRESET") }
    }

    var themeMode: String? {
        get { value(for: "THEME_MODE") }
        set { setValue(newValue, for: "THEME_MODE") }
    }

    var titleMode: String? {
        get { value(for: "TAVS_TITLE_MODE") }
        set { setValue(newValue, for: "TAVS_TITLE_MODE") }
    }

    var faceMode: String? {
        get { value(for: "TAVS_FACE_MODE") }
        set { setValue(newValue, for: "TAVS_FACE_MODE") }
    }

    var compactTheme: String? {
        get { value(for: "TAVS_COMPACT_THEME") }
        set { setValue(newValue, for: "TAVS_COMPACT_THEME") }
    }

    var identityMode: String? {
        get { value(for: "TAVS_IDENTITY_MODE") }
        set { setValue(newValue, for: "TAVS_IDENTITY_MODE") }
    }

    var dirIconType: String? {
        get { value(for: "TAVS_DIR_ICON_TYPE") }
        set { setValue(newValue, for: "TAVS_DIR_ICON_TYPE") }
    }

    var stylishBackgrounds: Bool? {
        get { value(for: "ENABLE_STYLISH_BACKGROUNDS").flatMap { $0 == "true" ? true : ($0 == "false" ? false : nil) } }
        set { setValue(newValue.map { $0 ? "true" : "false" }, for: "ENABLE_STYLISH_BACKGROUNDS") }
    }

    var lightDarkSwitching: Bool? {
        get { value(for: "ENABLE_LIGHT_DARK_SWITCHING").flatMap { $0 == "true" ? true : ($0 == "false" ? false : nil) } }
        set { setValue(newValue.map { $0 ? "true" : "false" }, for: "ENABLE_LIGHT_DARK_SWITCHING") }
    }

    // Pause background color as `#RRGGBB`. Stored as a hex string so the
    // Broadcaster can pass it straight into OSC 11. Invalid/malformed values
    // fall through to the default when consumed.
    var pauseBgDark: String? {
        get { value(for: "TAVS_PAUSE_BG_DARK") }
        set { setValue(newValue, for: "TAVS_PAUSE_BG_DARK") }
    }

    var pauseBgLight: String? {
        get { value(for: "TAVS_PAUSE_BG_LIGHT") }
        set { setValue(newValue, for: "TAVS_PAUSE_BG_LIGHT") }
    }

    var pauseFgDark: String? {
        get { value(for: "TAVS_PAUSE_FG_DARK") }
        set { setValue(newValue, for: "TAVS_PAUSE_FG_DARK") }
    }

    var pauseFgLight: String? {
        get { value(for: "TAVS_PAUSE_FG_LIGHT") }
        set { setValue(newValue, for: "TAVS_PAUSE_FG_LIGHT") }
    }

    // MARK: - Save

    func save() throws {
        let content = lines.map { $0.raw }.joined(separator: "\n")
        let data = Data(content.utf8)
        try data.write(to: url, options: .atomic)
    }

    // MARK: - Internal

    private func value(for key: String) -> String? {
        for line in lines.reversed() {
            if case .keyValue(let k, let v, _) = line, k == key {
                return v
            }
        }
        return nil
    }

    private func setValue(_ newValue: String?, for key: String) {
        guard let newValue = newValue else { return }

        for i in lines.indices.reversed() {
            if case .keyValue(let k, _, _) = lines[i], k == key {
                lines[i] = .keyValue(key: k, value: newValue, raw: "\(key)=\"\(newValue)\"")
                return
            }
        }
        lines.append(.keyValue(key: key, value: newValue, raw: "\(key)=\"\(newValue)\""))
    }

    // MARK: - Parser

    private enum ConfLine {
        case comment(raw: String)
        case blank(raw: String)
        case keyValue(key: String, value: String, raw: String)
        case unknown(raw: String)

        var raw: String {
            switch self {
            case .comment(let r), .blank(let r), .unknown(let r): return r
            case .keyValue(_, _, let r): return r
            }
        }
    }

    private static func parse(_ content: String) -> [ConfLine] {
        let rawLines = content.components(separatedBy: "\n")
        var result: [ConfLine] = []

        for rawLine in rawLines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                result.append(.blank(raw: rawLine))
            } else if trimmed.hasPrefix("#") {
                result.append(.comment(raw: rawLine))
            } else if let eqRange = rawLine.range(of: "=") {
                let key = String(rawLine[rawLine.startIndex..<eqRange.lowerBound])
                    .trimmingCharacters(in: .whitespaces)
                var val = String(rawLine[eqRange.upperBound...])
                    .trimmingCharacters(in: .whitespaces)
                if val.hasPrefix("\"") && val.hasSuffix("\"") && val.count >= 2 {
                    val = String(val.dropFirst().dropLast())
                }
                result.append(.keyValue(key: key, value: val, raw: rawLine))
            } else {
                result.append(.unknown(raw: rawLine))
            }
        }

        return result
    }
}
