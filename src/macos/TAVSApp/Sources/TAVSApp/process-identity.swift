import Foundation
import Darwin

struct ProcessGeneration: Codable, Hashable {
    let pid: Int32
    let startSeconds: UInt64
    let startMicroseconds: UInt64
}

struct ProcessIdentity {
    let generation: ProcessGeneration
    let parentPID: UInt32
    let group: UInt32
    let device: UInt32
    let foregroundGroup: UInt32

    static func inspect(_ pid: Int32) -> ProcessIdentity? {
        guard pid > 0 else { return nil }
        var info = proc_bsdinfo()
        let size = MemoryLayout<proc_bsdinfo>.size
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(size)) == size,
              info.pbi_pid == UInt32(pid), info.pbi_start_tvsec > 0,
              info.pbi_start_tvusec < 1_000_000, info.pbi_status != SZOMB,
              info.pbi_flags & UInt32(PROC_FLAG_INEXIT) == 0 else { return nil }
        return ProcessIdentity(
            generation: ProcessGeneration(pid: pid, startSeconds: info.pbi_start_tvsec,
                                          startMicroseconds: info.pbi_start_tvusec),
            parentPID: info.pbi_ppid, group: info.pbi_pgid, device: info.e_tdev,
            foregroundGroup: info.e_tpgid
        )
    }

    static func deviceNumber(_ path: String) -> UInt32? {
        var value = stat()
        guard path.hasPrefix("/dev/tty"), lstat(path, &value) == 0,
              value.st_mode & S_IFMT == S_IFCHR else { return nil }
        return UInt32(bitPattern: value.st_rdev)
    }

    static func foregroundFamilyContains(
        producer: ProcessGeneration, foreground: ProcessGeneration, device: UInt32,
        lookup: (Int32) -> ProcessIdentity? = inspect
    ) -> Bool {
        guard device != UInt32.max,
              let source = lookup(producer.pid), source.generation == producer,
              let current = lookup(foreground.pid), current.generation == foreground,
              source.device == device, current.device == device,
              current.foregroundGroup > 0, current.foregroundGroup <= UInt32(Int32.max),
              current.group == current.foregroundGroup,
              source.group == current.foregroundGroup,
              source.foregroundGroup == current.foregroundGroup else { return false }
        return true
    }
}
