import Foundation
import Darwin

enum LockStateEntry {
    static func handle(_ args: [String]) -> Bool {
        if args.count == 3, args[1] == "--validate-config", args[2] == "--lock-state-capabilities" {
            print("tavs-lock-state-schema=1")
            exit(0)
        }
        guard args.count > 1, args[1] == "--lock-state-update" else { return false }
        do { print(try update(args)); exit(0) }
        catch { fputs("Lock state mutation unavailable.\n", stderr); exit(1) }
    }

    static func update(_ args: [String]) throws -> Int64 {
        guard args.count >= 5, args[2].hasPrefix("/") else { throw POSIXError(.EINVAL) }
        let url = URL(fileURLWithPath: args[2]), operation = args[3]
        let now = Int64(Date().timeIntervalSince1970)
        func epoch(_ value: String) throws -> Int64 {
            guard !value.isEmpty, value.allSatisfy({ $0.isASCII && $0.isNumber }),
                  let number = Int64(value) else { throw POSIXError(.EINVAL) }
            return number
        }
        func color(_ value: String) throws -> String {
            if value.isEmpty { return "" }
            guard let normalized = PauseVisual.normalizedHexColor(value) else { throw POSIXError(.EINVAL) }
            return normalized
        }
        let state: LockStateData
        switch operation {
        case "now" where args.count == 7:
            let until = try epoch(args[4]), bg = try color(args[5]), fg = try color(args[6])
            guard until > now else { throw POSIXError(.EINVAL) }
            state = try LockStateWriter.update(at: url) { existing in
                let previousEnd = existing.map { $0.locked ? $0.lockUntilEpoch : 0 } ?? 0
                return LockStateData(locked: true, reason: .manual, lockUntilEpoch: max(until, previousEnd),
                    unlockUntilEpoch: 0, writtenEpoch: now, lockBg: bg, lockFg: fg)
            }
        case "grant" where args.count == 5:
            let until = try epoch(args[4])
            guard until > now else { throw POSIXError(.EINVAL) }
            state = try LockStateWriter.update(at: url) { existing in
                guard var current = existing else { throw POSIXError(.ENOENT) }
                current.unlockUntilEpoch = until; current.writtenEpoch = now
                return current
            }
        case "replace" where args.count == 10:
            guard ["true", "false"].contains(args[4]), let reason = LockReason(rawValue: args[5]) else {
                throw POSIXError(.EINVAL)
            }
            state = try LockStateData(locked: args[4] == "true", reason: reason,
                lockUntilEpoch: epoch(args[6]), unlockUntilEpoch: epoch(args[7]), writtenEpoch: now,
                lockBg: color(args[8]), lockFg: color(args[9]))
            try LockStateWriter.write(state, to: url)
        default: throw POSIXError(.EINVAL)
        }
        return state.lockUntilEpoch
    }
}
