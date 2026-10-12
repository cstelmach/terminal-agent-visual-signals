import XCTest
import Darwin
@testable import TAVSApp

final class ProcessIdentityTests: XCTestCase {
    func testOwnGenerationIsStableAndUnavailablePIDIsNotGuessed() throws {
        let first = try XCTUnwrap(ProcessIdentity.inspect(getpid()))
        XCTAssertEqual(first.generation, ProcessIdentity.inspect(getpid())?.generation)
        XCTAssertGreaterThan(first.generation.startSeconds, 0)
        XCTAssertNil(ProcessIdentity.inspect(-1))
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

    private func record(_ pid: Int32, group: UInt32, device: UInt32 = 123) -> ProcessIdentity {
        ProcessIdentity(generation: generation(pid), parentPID: 1, group: group,
                        device: device, foregroundGroup: 10)
    }
}
