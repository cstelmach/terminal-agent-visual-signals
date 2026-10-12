import Foundation

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
