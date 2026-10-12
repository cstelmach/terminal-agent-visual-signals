import Foundation
import Darwin

enum TerminalConfigurationError: Error { case unavailable, unresolvedAppearance }

enum TerminalRenderer {
    struct Colors: Equatable {
        let background: String
        let foreground: String

        init?(background: String, foreground: String) {
            guard let background = PauseVisual.normalizedHexColor(background),
                  let foreground = PauseVisual.normalizedHexColor(foreground) else { return nil }
            self.background = background
            self.foreground = foreground
        }
    }

    static func configuredColors(executable: URL, configurationFiles: [URL], runner: ProcessRunner) throws -> Colors {
        guard executable.isFileURL else { throw TerminalConfigurationError.unavailable }
        var configured = false
        for file in configurationFiles {
            guard file.isFileURL else { throw TerminalConfigurationError.unavailable }
            var info = stat()
            if stat(file.path, &info) != 0 {
                guard errno == ENOENT else { throw TerminalConfigurationError.unavailable }
                continue
            }
            guard info.st_mode & S_IFMT == S_IFREG, access(file.path, R_OK) == 0 else {
                throw TerminalConfigurationError.unavailable
            }
            configured = configured || info.st_size > 0
        }
        // Default-loading actions can create a template when no configuration exists.
        let arguments: [String]
        if configured {
            _ = try runner.runBounded(executableURL: executable, arguments: ["+validate-config"], timeout: 2)
            arguments = ["+show-config", "--changes-only=false", "--no-pager"]
        } else { arguments = ["+show-config", "--default", "--no-pager"] }
        return try parseConfiguration(runner.runBounded(executableURL: executable, arguments: arguments, timeout: 2))
    }

    static func parseConfiguration(_ data: Data) throws -> Colors {
        guard let text = String(data: data, encoding: .utf8) else { throw TerminalConfigurationError.unavailable }
        var fields: [String: String] = [:]
        for line in text.split(separator: "\n") {
            guard let separator = line.firstIndex(of: "=") else { continue }
            let key = line[..<separator].trimmingCharacters(in: .whitespacesAndNewlines)
            guard ["background", "foreground", "theme"].contains(key) else { continue }
            guard fields[key] == nil else { throw TerminalConfigurationError.unavailable }
            fields[key] = line[line.index(after: separator)...].trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let background = fields["background"], let foreground = fields["foreground"],
              let theme = fields["theme"], let colors = Colors(background: background, foreground: foreground) else {
            throw TerminalConfigurationError.unavailable
        }
        if theme.split(separator: ",").contains(where: {
            let value = $0.trimmingCharacters(in: .whitespaces)
            return value.hasPrefix("light:") || value.hasPrefix("dark:")
        }) { throw TerminalConfigurationError.unresolvedAppearance }
        return colors
    }

    static func previewBackground(ordinary: String?, colors: Colors) -> String? {
        let background: String
        if ordinary == nil || ordinary == "reset" { background = colors.background }
        else {
            guard let value = PauseVisual.normalizedHexColor(ordinary) else { return nil }
            background = value
        }
        let baseline = PauseVisual.contrastRatio(background, colors.foreground)
        let minimum = min(4.5, baseline)
        let tint = PauseVisual.relativeLuminance(background) < 0.5 ? "#758BD6" : "#405EBB"
        let base = PauseVisual.rgbComponents(background), cue = PauseVisual.rgbComponents(tint)
        for amount in [0.20, 0.16, 0.12, 0.08] {
            let channels = [(base.red, cue.red), (base.green, cue.green), (base.blue, cue.blue)]
            let values = channels.map { Int((($0.0 * (1 - amount)) + ($0.1 * amount)) * 255 + 0.5) }
            let distance = zip(values, [base.red, base.green, base.blue]).reduce(0) {
                $0 + abs($1.0 - Int($1.1 * 255 + 0.5))
            }
            let candidate = String(format: "#%02X%02X%02X", values[0], values[1], values[2])
            // The distance bound rejects negligible changes; visibility still needs native acceptance.
            if distance >= 24, PauseVisual.contrastRatio(candidate, colors.foreground) >= minimum {
                return candidate
            }
        }
        return nil
    }
}
