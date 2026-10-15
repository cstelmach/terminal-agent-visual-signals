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
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.size
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        // Public kernel metadata also covers root-owned login ancestors of user shells.
        guard sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0) == 0 else { return nil }
        return fromKernel(info, pid: pid, byteCount: size)
    }

    static func fromKernel(_ info: kinfo_proc, pid: Int32, byteCount: Int) -> ProcessIdentity? {
        let start = info.kp_proc.p_un.__p_starttime
        guard pid > 0, byteCount == MemoryLayout<kinfo_proc>.size,
              info.kp_proc.p_pid == pid, start.tv_sec > 0,
              start.tv_usec >= 0, start.tv_usec < 1_000_000,
              [Int8(SRUN), Int8(SSLEEP), Int8(SSTOP)].contains(info.kp_proc.p_stat),
              info.kp_proc.p_flag & P_WEXIT == 0,
              info.kp_eproc.e_ppid >= 0, info.kp_eproc.e_pgid >= 0,
              info.kp_eproc.e_tpgid >= -1 else { return nil }
        return ProcessIdentity(
            generation: ProcessGeneration(pid: pid, startSeconds: UInt64(start.tv_sec),
                                          startMicroseconds: UInt64(start.tv_usec)),
            parentPID: UInt32(info.kp_eproc.e_ppid), group: UInt32(info.kp_eproc.e_pgid),
            device: UInt32(bitPattern: info.kp_eproc.e_tdev),
            foregroundGroup: UInt32(bitPattern: info.kp_eproc.e_tpgid)
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
