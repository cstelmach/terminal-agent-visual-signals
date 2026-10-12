import Foundation

struct TerminalRender {
    let background: String?
    let title: String?
    private let paletteAction: String
    private let palette: [String?]
    private let imageAction: String
    private let imagePath: String
    private let bell: Bool

    init(_ data: Data) throws {
        guard data.count <= 16_384, data.last == 0 else { throw TerminalVisualStateError.invalidRecord }
        let parts = data.split(separator: 0, omittingEmptySubsequences: false)
        guard parts.count == 24, parts.last?.isEmpty == true else { throw TerminalVisualStateError.invalidRecord }
        let fields = try parts.dropLast().map { value -> String in
            guard let text = String(data: Data(value), encoding: .utf8) else {
                throw TerminalVisualStateError.invalidRecord
            }
            return text
        }
        if fields[0].isEmpty { background = nil }
        else {
            guard let color = TerminalVisualStateStore.normalizedBackground(fields[0]) else {
                throw TerminalVisualStateError.invalidRecord
            }
            background = color
        }
        guard ["", "set", "reset"].contains(fields[1]), ["0", "1"].contains(fields[18]),
              ["", "iterm2-set", "iterm2-clear"].contains(fields[20]),
              ["0", "1"].contains(fields[22]) else { throw TerminalVisualStateError.invalidRecord }
        paletteAction = fields[1]
        palette = try fields[2..<18].map { value in
            if value.isEmpty { return nil }
            guard fields[1] == "set", let color = PauseVisual.normalizedHexColor(value) else {
                throw TerminalVisualStateError.invalidRecord
            }
            return color
        }
        guard fields[19].utf8.count <= 8_192,
              Self.safeText(fields[19]),
              fields[18] == "1" || fields[19].isEmpty else { throw TerminalVisualStateError.invalidRecord }
        title = fields[18] == "1" ? fields[19] : nil
        guard fields[21].utf8.count <= 4_096,
              Self.safeText(fields[21]) else {
            throw TerminalVisualStateError.invalidRecord
        }
        if fields[20] == "iterm2-set" {
            guard fields[21].hasPrefix("/") else { throw TerminalVisualStateError.invalidRecord }
        } else {
            guard fields[21].isEmpty else { throw TerminalVisualStateError.invalidRecord }
        }
        imageAction = fields[20]; imagePath = fields[21]; bell = fields[22] == "1"
    }

    var beforeBackground: Data {
        if paletteAction == "reset" { return Data("\u{1B}]104\u{1B}\\".utf8) }
        guard paletteAction == "set" else { return Data() }
        var colors = ""
        for (index, color) in palette.enumerated() {
            guard let color = color else { continue }
            let hex = Array(color.dropFirst())
            colors += ";\(index);rgb:\(String(hex[0...1]))/\(String(hex[2...3]))/\(String(hex[4...5]))"
        }
        return colors.isEmpty ? Data() : Data("\u{1B}]4\(colors)\u{1B}\\".utf8)
    }

    private static func safeText(_ text: String) -> Bool {
        // C0/C1 can control the terminal; format scalars also form joined emoji.
        text.unicodeScalars.allSatisfy { $0.value >= 32 && !((127...159).contains($0.value)) }
    }

    func afterBackground(synthetic: Bool) -> Data {
        var text = title.map { "\u{1B}]0;\($0)\u{1B}\\" } ?? ""
        if imageAction == "iterm2-set" {
            text += "\u{1B}]1337;SetBackgroundImageFile=\(Data(imagePath.utf8).base64EncodedString())\u{07}"
        } else if imageAction == "iterm2-clear" {
            text += "\u{1B}]1337;SetBackgroundImageFile=\u{07}"
        }
        if bell && !synthetic { text += "\u{07}" }
        return Data(text.utf8)
    }
}
