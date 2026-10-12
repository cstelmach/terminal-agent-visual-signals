import Foundation
import Darwin

enum TerminalConfigurationError: Error { case unavailable, unresolvedAppearance }

enum TerminalRenderer {
    struct Colors: Equatable, Codable {
        let background: String
        let foreground: String

        init?(background: String, foreground: String) {
            guard let background = PauseVisual.normalizedHexColor(background),
                  let foreground = PauseVisual.normalizedHexColor(foreground) else { return nil }
            self.background = background
            self.foreground = foreground
        }

        init(from decoder: Decoder) throws {
            try requireVisualKeys(decoder, ["background", "foreground"])
            let values = try decoder.container(keyedBy: CodingKeys.self)
            guard let colors = Self(background: try values.decode(String.self, forKey: .background),
                                    foreground: try values.decode(String.self, forKey: .foreground)) else {
                throw TerminalVisualStateError.invalidRecord
            }
            self = colors
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
        guard let background = resolvedBackground(ordinary, colors: colors) else { return nil }
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

    static func focusBackground(ordinary: String?, colors: Colors) -> String? {
        guard let background = resolvedBackground(ordinary, colors: colors) else { return nil }
        let rgb = PauseVisual.rgbComponents(background)
        let channels = [rgb.red, rgb.green, rgb.blue]
        let linear = channels.map(PauseVisual.linearized)
        let luminance = PauseVisual.relativeLuminance(background)
        let minimum = min(4.5, PauseVisual.contrastRatio(background, colors.foreground))
        // Linear-light desaturation preserves luminance before a bounded neutral adjustment.
        for shift in [0.0, -0.04, 0.04, -0.08, 0.08] {
            let neutral = max(0, min(1, luminance + shift))
            for amount in [0.75, 0.5, 1.0] {
                let values = linear.map { channel -> Int in
                    let value = channel * (1 - amount) + neutral * amount
                    let encoded = value <= 0.0031308 ? value * 12.92 : 1.055 * pow(value, 1 / 2.4) - 0.055
                    return Int(encoded * 255 + 0.5)
                }
                let distance = zip(values, channels).reduce(0) {
                    $0 + abs($1.0 - Int($1.1 * 255 + 0.5))
                }
                let candidate = String(format: "#%02X%02X%02X", values[0], values[1], values[2])
                if distance >= 24,
                   abs(PauseVisual.relativeLuminance(candidate) - luminance) <= 0.08,
                   PauseVisual.contrastRatio(candidate, colors.foreground) >= minimum { return candidate }
            }
        }
        return nil
    }

    private static func resolvedBackground(_ ordinary: String?, colors: Colors) -> String? {
        guard let ordinary = ordinary, ordinary != "reset" else { return colors.background }
        return PauseVisual.normalizedHexColor(ordinary)
    }
}
