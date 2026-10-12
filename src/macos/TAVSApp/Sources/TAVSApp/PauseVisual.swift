import Foundation

struct PauseVisual: Equatable {
    let backgroundColor: String
    let foregroundColor: String

    init(backgroundColor: String?, foregroundColor: String?, defaultBackgroundColor: String) {
        let defaultBackground = Self.normalizedHexColor(defaultBackgroundColor)!
        let resolvedBackground = Self.normalizedHexColor(backgroundColor) ?? defaultBackground

        self.backgroundColor = resolvedBackground
        self.foregroundColor = Self.normalizedHexColor(foregroundColor)
            ?? Self.readableForeground(for: resolvedBackground)
    }

    static func normalizedHexColor(_ raw: String?) -> String? {
        guard let raw = raw else { return nil }
        let color = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard color.count == 7, color.first == "#" else { return nil }

        let hex = String(color.dropFirst())
        guard hex.rangeOfCharacter(from: CharacterSet(charactersIn: "0123456789ABCDEF").inverted) == nil else {
            return nil
        }
        return color
    }

    private static func readableForeground(for background: String) -> String {
        let softCandidates = [
            UserConfStore.defaultPauseFgDark,
            UserConfStore.defaultPauseFgLight,
        ]
        let softContrasts = softCandidates.map { ($0, contrastRatio($0, background)) }
        let bestSoft = softContrasts.max { $0.1 < $1.1 }!

        if bestSoft.1 >= 4.5 {
            return bestSoft.0
        }

        let hardCandidates = ["#FFFFFF", "#000000"]
        return hardCandidates.max {
            contrastRatio($0, background) < contrastRatio($1, background)
        }!
    }

    static func contrastRatio(_ first: String, _ second: String) -> Double {
        let firstLuminance = relativeLuminance(first)
        let secondLuminance = relativeLuminance(second)
        return (max(firstLuminance, secondLuminance) + 0.05)
            / (min(firstLuminance, secondLuminance) + 0.05)
    }

    static func relativeLuminance(_ color: String) -> Double {
        let components = rgbComponents(color)
        return 0.2126 * linearized(components.red)
            + 0.7152 * linearized(components.green)
            + 0.0722 * linearized(components.blue)
    }

    static func rgbComponents(_ color: String) -> (red: Double, green: Double, blue: Double) {
        let hex = String(color.dropFirst())
        let red = Int(hex.prefix(2), radix: 16)!
        let greenStart = hex.index(hex.startIndex, offsetBy: 2)
        let greenEnd = hex.index(hex.startIndex, offsetBy: 4)
        let green = Int(hex[greenStart..<greenEnd], radix: 16)!
        let blue = Int(hex.suffix(2), radix: 16)!

        return (
            red: Double(red) / 255.0,
            green: Double(green) / 255.0,
            blue: Double(blue) / 255.0
        )
    }

    static func linearized(_ channel: Double) -> Double {
        if channel <= 0.03928 {
            return channel / 12.92
        }
        return pow((channel + 0.055) / 1.055, 2.4)
    }
}
