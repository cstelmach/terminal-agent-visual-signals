import XCTest
import Darwin
@testable import TAVSApp

final class ProcessIdentityTests: XCTestCase {
    func testPublicKernelIdentityIncludesThePrivilegedSystemParent() throws {
        let parent = try XCTUnwrap(ProcessIdentity.inspect(1))
        XCTAssertEqual(parent.generation.pid, 1)
        XCTAssertGreaterThan(parent.generation.startSeconds, 0)
        XCTAssertEqual(parent.generation, ProcessIdentity.inspect(1)?.generation)
    }

    func testOwnIdentityMatchesTheIndependentLibprocSnapshot() throws {
        var info = proc_bsdinfo()
        XCTAssertEqual(proc_pidinfo(getpid(), PROC_PIDTBSDINFO, 0, &info,
            Int32(MemoryLayout<proc_bsdinfo>.size)), Int32(MemoryLayout<proc_bsdinfo>.size))
        let value = try XCTUnwrap(ProcessIdentity.inspect(getpid()))
        XCTAssertEqual(value.generation.startSeconds, info.pbi_start_tvsec)
        XCTAssertEqual(value.generation.startMicroseconds, info.pbi_start_tvusec)
        XCTAssertEqual(value.parentPID, info.pbi_ppid)
        XCTAssertEqual(value.group, info.pbi_pgid)
        XCTAssertEqual(value.device, info.e_tdev)
        XCTAssertEqual(value.foregroundGroup, info.e_tpgid)
    }

    func testOwnGenerationIsStableAndUnavailablePIDIsNotGuessed() throws {
        let first = try XCTUnwrap(ProcessIdentity.inspect(getpid()))
        XCTAssertEqual(first.generation, ProcessIdentity.inspect(getpid())?.generation)
        XCTAssertGreaterThan(first.generation.startSeconds, 0)
        XCTAssertNil(ProcessIdentity.inspect(-1))
        XCTAssertNil(ProcessIdentity.inspect(Int32.max))
    }

    func testKernelSnapshotRejectsIncompleteOrInvalidIdentity() throws {
        let info = kernelRecord()
        let size = MemoryLayout<kinfo_proc>.size
        for count in [0, size - 1, size + 1] {
            XCTAssertNil(ProcessIdentity.fromKernel(info, pid: 43, byteCount: count))
        }
        let mutations: [(inout kinfo_proc) -> Void] = [
            { $0.kp_proc.p_pid = 44 },
            { $0.kp_proc.p_un.__p_starttime.tv_sec = 0 },
            { $0.kp_proc.p_un.__p_starttime.tv_sec = -1 },
            { $0.kp_proc.p_un.__p_starttime.tv_usec = -1 },
            { $0.kp_proc.p_un.__p_starttime.tv_usec = 1_000_000 },
            { $0.kp_proc.p_stat = Int8(SIDL) },
            { $0.kp_proc.p_stat = Int8(SZOMB) },
            { $0.kp_proc.p_stat = 0 },
            { $0.kp_proc.p_stat = 99 },
            { $0.kp_proc.p_flag |= P_WEXIT },
            { $0.kp_eproc.e_ppid = -1 },
            { $0.kp_eproc.e_pgid = -1 },
            { $0.kp_eproc.e_tpgid = -2 }
        ]
        for mutation in mutations {
            var changed = info
            mutation(&changed)
            XCTAssertNil(ProcessIdentity.fromKernel(changed, pid: 43, byteCount: size))
        }
        let value = try XCTUnwrap(ProcessIdentity.fromKernel(info, pid: 43, byteCount: size))
        XCTAssertEqual(value.generation, ProcessGeneration(pid: 43, startSeconds: 100,
                                                          startMicroseconds: 123))
        XCTAssertEqual(value.parentPID, 1)
        XCTAssertEqual(value.group, 43)
        XCTAssertEqual(value.device, 123)
        XCTAssertEqual(value.foregroundGroup, 43)
    }

    func testKernelSnapshotPreservesNoTTYAndOrdinary64BitFlag() throws {
        var info = kernelRecord()
        info.kp_proc.p_flag = P_LP64
        info.kp_eproc.e_tdev = -1
        info.kp_eproc.e_tpgid = -1
        let value = try XCTUnwrap(ProcessIdentity.fromKernel(
            info, pid: 43, byteCount: MemoryLayout<kinfo_proc>.size))
        XCTAssertEqual(value.device, UInt32.max)
        XCTAssertEqual(value.foregroundGroup, UInt32.max)
        for state in [SRUN, SSLEEP, SSTOP] {
            info.kp_proc.p_stat = Int8(state)
            XCTAssertNotNil(ProcessIdentity.fromKernel(
                info, pid: 43, byteCount: MemoryLayout<kinfo_proc>.size))
        }
    }

    func testPIDReuseIsDifferentGeneration() {
        XCTAssertNotEqual(generation(10), ProcessGeneration(pid: 10, startSeconds: 2, startMicroseconds: 1))
        XCTAssertNotEqual(generation(10), ProcessGeneration(pid: 10, startSeconds: 1, startMicroseconds: 2))
    }

    func testForegroundFamilyRequiresCurrentGenerationsTTYAndGroup() {
        var records = [Int32: ProcessIdentity]()
        records[10] = record(10, group: 10)
        records[11] = record(11, group: 10)
        let lookup: (Int32) -> ProcessIdentity? = { records[$0] }
        XCTAssertTrue(ProcessIdentity.foregroundFamilyContains(
            producer: generation(11), foreground: generation(10), device: 123, lookup: lookup
        ))
        records[11] = record(11, group: 11)
        XCTAssertFalse(ProcessIdentity.foregroundFamilyContains(
            producer: generation(11), foreground: generation(10), device: 123, lookup: lookup
        ))
        records[11] = record(11, group: 10, device: 456)
        XCTAssertFalse(ProcessIdentity.foregroundFamilyContains(
            producer: generation(11), foreground: generation(10), device: 123, lookup: lookup
        ))
        records[11] = nil
        XCTAssertFalse(ProcessIdentity.foregroundFamilyContains(
            producer: generation(11), foreground: generation(10), device: 123, lookup: lookup
        ))
    }

    func testStaleGenerationAndNoControllingTTYAreIneligible() {
        let foreground = record(10, group: 10)
        let stale = ProcessGeneration(pid: 11, startSeconds: 99, startMicroseconds: 1)
        XCTAssertFalse(ProcessIdentity.foregroundFamilyContains(
            producer: stale, foreground: generation(10), device: 123,
            lookup: { $0 == 10 ? foreground : self.record(11, group: 10) }
        ))
        XCTAssertFalse(ProcessIdentity.foregroundFamilyContains(
            producer: generation(10), foreground: generation(10), device: UInt32.max,
            lookup: { _ in foreground }
        ))
        let invalid = ProcessIdentity(generation: generation(10), parentPID: 1,
                                      group: UInt32.max, device: 123, foregroundGroup: UInt32.max)
        XCTAssertFalse(ProcessIdentity.foregroundFamilyContains(
            producer: generation(10), foreground: generation(10), device: 123,
            lookup: { _ in invalid }
        ))
    }

    private func generation(_ pid: Int32) -> ProcessGeneration {
        ProcessGeneration(pid: pid, startSeconds: 1, startMicroseconds: 1)
    }

    private func kernelRecord() -> kinfo_proc {
        var info = kinfo_proc()
        info.kp_proc.p_pid = 43
        info.kp_proc.p_un.__p_starttime.tv_sec = 100
        info.kp_proc.p_un.__p_starttime.tv_usec = 123
        info.kp_proc.p_stat = Int8(SSLEEP)
        info.kp_eproc.e_ppid = 1
        info.kp_eproc.e_pgid = 43
        info.kp_eproc.e_tdev = 123
        info.kp_eproc.e_tpgid = 43
        return info
    }

    private func record(_ pid: Int32, group: UInt32, device: UInt32 = 123) -> ProcessIdentity {
        ProcessIdentity(generation: generation(pid), parentPID: 1, group: group,
                        device: device, foregroundGroup: 10)
    }
}
