import CryptoKit
import Foundation

// ==============================================================================
// Unlock challenge logic (spec D2, section 2.4) — Swift twin of challenge.sh.
// ==============================================================================
// The password hash spec is dual-implemented and pinned by
// tests/integration/challenge-parity.bats via `TAVSApp --verify-password-hash`.
// Puzzles are generated and verified ephemerally per prompt on each side, so
// the sentence pools do NOT need to match the CLI's.
// ==============================================================================

enum ChallengeType: String {
    case password
    case puzzle
    case both
}

struct ChallengeConfig: Equatable {
    var type: ChallengeType
    var saltHex: String
    var hashHex: String
    var sentencesFile: String
}

enum ChallengeVerifier {
    // Spec 2.4: lowercase-hex SHA256(UTF8(salt_hex_string + password)).
    // The salt is concatenated as the LITERAL hex string, not decoded bytes.
    static func passwordHash(saltHex: String, password: String) -> String {
        let digest = SHA256.hash(data: Data((saltHex + password).utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // "the quick brown fox" -> "het uickq rownb oxf"; single-letter words map
    // to themselves.
    static func puzzleTransform(_ sentence: String) -> String {
        sentence.split(separator: " ").map { word -> String in
            String(word.dropFirst()) + String(word.prefix(1))
        }.joined(separator: " ")
    }

    // Mirrors challenge.sh degradation rules: unknown type or a password type
    // without stored salt+hash falls back to the puzzle (never a lockout, D3).
    static func loadConfig(at url: URL) -> ChallengeConfig {
        var fields: [String: String] = [:]
        if let contents = try? String(contentsOf: url, encoding: .utf8) {
            for line in contents.split(separator: "\n") {
                guard let eq = line.firstIndex(of: "=") else { continue }
                let key = String(line[line.startIndex..<eq])
                var value = String(line[line.index(after: eq)...])
                if value.hasPrefix("\"") { value.removeFirst() }
                if value.hasSuffix("\"") { value.removeLast() }
                fields[key] = value
            }
        }
        var type = ChallengeType(rawValue: fields["CHALLENGE_TYPE"] ?? "") ?? .puzzle
        let salt = fields["PASSWORD_SALT_HEX"] ?? ""
        let hash = fields["PASSWORD_HASH_HEX"] ?? ""
        if type != .puzzle && (salt.isEmpty || hash.isEmpty) {
            type = .puzzle
        }
        return ChallengeConfig(
            type: type, saltHex: salt, hashHex: hash,
            sentencesFile: fields["PUZZLE_SENTENCES_FILE"] ?? ""
        )
    }

    static func verifyPassword(_ password: String, config: ChallengeConfig) -> Bool {
        passwordHash(saltHex: config.saltHex, password: password) == config.hashHex
    }

    static func randomSentence(config: ChallengeConfig) -> String {
        if !config.sentencesFile.isEmpty,
           let contents = try? String(contentsOf: URL(fileURLWithPath: config.sentencesFile), encoding: .utf8) {
            let lines = contents.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
            if let pick = lines.randomElement() { return pick }
        }
        return DefaultPuzzleSentences.all.randomElement()!
    }

    static func verifyPuzzle(answer: String, sentence: String) -> Bool {
        var trimmed = answer
        while let last = trimmed.last, last.isWhitespace {
            trimmed.removeLast()
        }
        return trimmed == puzzleTransform(sentence)
    }
}

// The app-side puzzle pool (lowercase words + single spaces, 6-10 words per
// line). Independent from src/core/challenge-sentences.txt by design.
enum DefaultPuzzleSentences {
    static let all: [String] = [
        "the quick brown fox jumps over the lazy dog",
        "a calm mind finishes the work before the deadline",
        "deep focus beats busy noise every single time",
        "small steps taken daily build the longest roads",
        "the patient gardener waits for the seed to grow",
        "clear water runs quietly under the old stone bridge",
        "good tools serve the hand that respects them",
        "the morning light falls softly on the empty desk",
        "slow breathing settles the racing thoughts at once",
        "every finished task clears space for better thinking",
        "the mountain path rewards those who keep walking",
        "quiet rooms help loud ideas find their shape",
        "strong habits grow from many small honest choices",
        "fresh air and short walks repair tired minds",
        "one clear goal beats ten scattered wishes daily",
        "the river finds its way around every rock",
        "honest work done slowly still arrives on time",
        "a short break now saves a long night later",
        "the empty page waits calmly for the first word",
        "steady hands finish what eager hands only start",
        "the wise carpenter measures twice and cuts once",
        "attention is the rarest gift you can give",
        "simple plans survive contact with the busy day",
        "rest is part of the work not its enemy",
        "the long road looks shorter after the first mile",
        "patience turns hard problems into small easy pieces",
        "kind words cost little and travel very far",
        "focus on the step and the summit will come",
        "a good night of sleep sharpens every tool",
        "real progress hides inside boring daily routines",
        "the closed door protects the open mind inside",
        "finish the small thing before starting the big one",
    ]
}
