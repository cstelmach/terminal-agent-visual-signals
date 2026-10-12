import XCTest
import JavaScriptCore
@testable import TAVSApp

final class GhosttyCatalogTests: XCTestCase {
    private let app = ProcessGeneration(pid: 10, startSeconds: 1, startMicroseconds: 1)

    private func reply(_ rows: [[String: Any]], focused: Bool? = nil) throws -> Data {
        var value: [String: Any] = ["surfaces": rows]
        if let focused = focused { value["focused"] = focused }
        return try JSONSerialization.data(withJSONObject: value)
    }

    private func row(_ id: String, tty: String = "/dev/ttys001", tab: String = "tab") -> [String: Any] {
        ["terminalID": id, "windowID": "window", "tabID": tab, "title": "same title",
         "directory": "/same", "tty": tty, "pid": 100, "selected": true]
    }

    func testDuplicateNamesStayDistinctAndNativeOrderIsPreserved() throws {
        let rows = try GhosttyCatalog.decode(reply([row("a"), row("b", tty: "/dev/ttys002")]), application: app)
        XCTAssertEqual(rows.map(\.id.terminalID), ["a", "b"])
        XCTAssertNotEqual(rows[0].id, rows[1].id)
        XCTAssertTrue(rows.allSatisfy { $0.mappingIssue == nil })
    }

    func testMovementKeepsIdentityButRestartChangesIt() throws {
        let first = try XCTUnwrap(GhosttyCatalog.decode(reply([row("a")]), application: app).first)
        let moved = try XCTUnwrap(GhosttyCatalog.decode(reply([row("a", tab: "moved")]), application: app).first)
        XCTAssertEqual(first.id, moved.id)
        let newer = ProcessGeneration(pid: 10, startSeconds: 2, startMicroseconds: 1)
        XCTAssertNotEqual(first.id, try GhosttyCatalog.decode(reply([row("a")]), application: newer)[0].id)
    }

    func testMissingAndAmbiguousTTYAreExplicitRows() throws {
        var missing = row("c"); missing.removeValue(forKey: "tty")
        let rows = try GhosttyCatalog.decode(reply([row("a"), row("b"), missing]), application: app)
        XCTAssertEqual(rows[0].mappingIssue, .ambiguousTTY)
        XCTAssertEqual(rows[1].mappingIssue, .ambiguousTTY)
        XCTAssertEqual(rows[2].mappingIssue, .missingTTY)
    }

    func testRejectsDuplicateNativeIDsMalformedRepliesAndPermissionDenial() throws {
        XCTAssertThrowsError(try GhosttyCatalog.decode(reply([row("a"), row("a")]), application: app))
        XCTAssertThrowsError(try GhosttyCatalog.decode(Data("{}".utf8), application: app))
        XCTAssertThrowsError(try GhosttyCatalog.decode(Data("{\"error\":\"permissionDenied\"}".utf8), application: app)) { error in
            XCTAssertEqual(error as? GhosttyCatalogError, .permissionDenied)
        }
    }

    func testInvalidTTYPathsCannotBecomeActionable() throws {
        for tty in ["/dev/tty", "/dev/ttys001\n", "/dev/ttys001/../../x", "/tmp/ttys001"] {
            let surface = try GhosttyCatalog.decode(reply([row("a", tty: tty)]), application: app)[0]
            XCTAssertEqual(surface.mappingIssue, .missingTTY, tty)
        }
    }

    func testDedicatedScopeFiltersRowsAndRejectsOtherNavigationBeforeNativeWork() throws {
        let runner = MockProcessRunner()
        let a = try GhosttyCatalog.decode(reply([row("a")]), application: app)[0]
        let b = try GhosttyCatalog.decode(reply([row("b", tty: "/dev/ttys002")]), application: app)[0]
        runner.boundedResults = [.success(try reply([row("a"),row("b",tty: "/dev/ttys002")]))]
        let catalog = GhosttyCatalog(processRunner: runner, application: { self.app }, allowedSurfaces: [a.id])
        let listed = expectation(description: "only dedicated rows")
        catalog.refresh { result in
            if case .success(let rows) = result { XCTAssertEqual(rows.map(\.id), [a.id]) }
            else { XCTFail("Scoped catalogue failed") }
            listed.fulfill()
        }
        wait(for: [listed], timeout: 2)
        let blocked = expectation(description: "foreign target")
        catalog.goTo(b) { result in
            if case .success = result { XCTFail("Out-of-scope target navigated") }
            XCTAssertEqual(runner.runCallLog.count, 1)
            blocked.fulfill()
        }
        wait(for: [blocked], timeout: 2)
    }

    func testRefreshCoalescesToOnePendingRequestAndRunsAwayFromMainThread() throws {
        let runner = MockProcessRunner()
        let data = try reply([row("a")])
        let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        var calls = 0
        runner.boundedHandler = { _, _, _ in
            XCTAssertFalse(Thread.isMainThread)
            calls += 1
            if calls == 1 {
                entered.signal()
                guard release.wait(timeout: .now() + 1) == .success else {
                    throw ProcessRunnerError.processTimedOut
                }
            }
            return data
        }
        let catalog = GhosttyCatalog(processRunner: runner, application: { self.app })
        let first = expectation(description: "first"), pending = expectation(description: "coalesced")
        pending.expectedFulfillmentCount = 4
        catalog.refresh { result in
            XCTAssertTrue(Thread.isMainThread)
            if case .failure(let error) = result { XCTFail("\(error)") }
            first.fulfill()
        }
        XCTAssertEqual(entered.wait(timeout: .now() + 1), .success)
        for _ in 0..<4 { catalog.refresh { _ in pending.fulfill() } }
        release.signal()
        wait(for: [first, pending], timeout: 2)
        XCTAssertEqual(calls, 2)
    }

    func testHeadlessSnapshotReturnsWithoutMainCallbackAndKeepsDedicatedScope() throws {
        XCTAssertTrue(Thread.isMainThread)
        let runner = MockProcessRunner()
        let data = try reply([row("a"), row("b", tty: "/dev/ttys002")])
        let allowed = GhosttySurfaceID(application: app, terminalID: "a")
        runner.boundedHandler = { _, args, timeout in
            XCTAssertFalse(Thread.isMainThread)
            XCTAssertEqual(timeout, 2)
            let request = try JSONSerialization.jsonObject(with: Data(try XCTUnwrap(args.last).utf8))
                as? [String: Any]
            XCTAssertEqual(request?["allowedIDs"] as? [String], ["a"])
            return data
        }
        let catalog = GhosttyCatalog(processRunner: runner, application: { self.app }, allowedSurfaces: [allowed])
        XCTAssertEqual(try catalog.snapshot().map(\.id), [allowed])
        XCTAssertEqual(runner.runCallLog.count, 1)
    }

    func testHeadlessSnapshotPreservesPermissionAndApplicationGenerationFailures() throws {
        let runner = MockProcessRunner()
        runner.boundedResults = [.success(Data("{\"error\":\"permissionDenied\"}".utf8))]
        let denied = GhosttyCatalog(processRunner: runner, application: { self.app })
        XCTAssertThrowsError(try denied.snapshot()) { error in
            XCTAssertEqual(error as? GhosttyCatalogError, .permissionDenied)
        }
        runner.boundedResults = [.success(try reply([row("a")]))]
        var calls = 0
        let changed = ProcessGeneration(pid: app.pid, startSeconds: 2, startMicroseconds: 1)
        let stale = GhosttyCatalog(processRunner: runner, application: {
            calls += 1
            return calls == 1 ? self.app : changed
        })
        XCTAssertThrowsError(try stale.snapshot()) { error in
            XCTAssertEqual(error as? GhosttyCatalogError, .staleApplication)
        }
    }

    func testGoToRejectsReusedTTYAndAcceptsConfirmedMovedSurface() throws {
        let runner = MockProcessRunner()
        let target = try GhosttyCatalog.decode(reply([row("a")]), application: app)[0]
        runner.boundedResults = [.success(try reply([row("a", tty: "/dev/ttys002")], focused: true))]
        let catalog = GhosttyCatalog(processRunner: runner, application: { self.app })
        let rejected = expectation(description: "TTY reuse")
        catalog.goTo(target) { result in
            if case .success = result { XCTFail("Reused TTY accepted") }
            rejected.fulfill()
        }
        wait(for: [rejected], timeout: 2)
        runner.boundedResults = [.success(try reply([row("a", tab: "new-tab")], focused: true))]
        let accepted = expectation(description: "moved")
        catalog.goTo(target) { result in
            if case .failure(let error) = result { XCTFail("\(error)") }
            accepted.fulfill()
        }
        wait(for: [accepted], timeout: 2)
    }

    func testGoToRejectsRestartAndUnconfirmedFocusWithoutAcknowledgement() throws {
        let runner = MockProcessRunner()
        let target = try GhosttyCatalog.decode(reply([row("a")]), application: app)[0]
        let changed = ProcessGeneration(pid: 10, startSeconds: 2, startMicroseconds: 1)
        let stale = GhosttyCatalog(processRunner: runner, application: { changed })
        let stopped = expectation(description: "stale rejected")
        stale.goTo(target) { result in
            if case .success = result { XCTFail("Stale target accepted") }
            XCTAssertEqual(runner.runCallLog.count, 0)
            stopped.fulfill()
        }
        wait(for: [stopped], timeout: 2)
        runner.boundedResults = [.success(try reply([row("a")], focused: false))]
        let catalog = GhosttyCatalog(processRunner: runner, application: { self.app })
        let failed = expectation(description: "focus not confirmed")
        catalog.goTo(target) { result in
            if case .success = result { XCTFail("Unconfirmed focus accepted") }
            failed.fulfill()
        }
        wait(for: [failed], timeout: 2)
    }

    func testScriptTakesIDsAsDataAndRevalidatesTTYBeforeExactFocus() throws {
        let context = try nativeContext()
        let request: [String: Any] = ["action": "focus", "terminalID": "quoted\";id", "tty": "/dev/ttys999", "pid": 10]
        let json = String(data: try JSONSerialization.data(withJSONObject: request), encoding: .utf8)!
        let run = try XCTUnwrap(context.objectForKeyedSubscript("run"))
        let wrong = run.call(withArguments: [[json]])?.toString() ?? ""
        XCTAssertTrue(wrong.contains("targetUnavailable"))
        XCTAssertEqual(context.objectForKeyedSubscript("calls")?.toInt32(), 0)
        var valid = request; valid["tty"] = "/dev/ttys001"
        let validJSON = String(data: try JSONSerialization.data(withJSONObject: valid), encoding: .utf8)!
        let result = run.call(withArguments: [[validJSON]])?.toString() ?? ""
        XCTAssertNil(context.exception)
        XCTAssertTrue(result.contains("\"focused\":true"))
        XCTAssertEqual(context.objectForKeyedSubscript("calls")?.toInt32(), 1)
        XCTAssertEqual(context.objectForKeyedSubscript("requestedPID")?.toInt32(), 10)
        _ = run.call(withArguments: [[validJSON]])
        XCTAssertEqual(context.objectForKeyedSubscript("calls")?.toInt32(), 1, "Already-focused retries send no extra focus")
        context.evaluateScript("""
        var duplicate = object({id:'duplicate',name:'same',tty:terminal.tty,pid:101});
        tab.terminals=array([terminal,duplicate]); application.terminals=array([terminal,duplicate]);
        focused='other';
        """)
        let ambiguous = run.call(withArguments: [[validJSON]])?.toString() ?? ""
        XCTAssertTrue(ambiguous.contains("targetUnavailable"))
        XCTAssertEqual(context.objectForKeyedSubscript("calls")?.toInt32(), 1)
    }

    func testAdapterPermissionDenialNeverFocuses() throws {
        let context = try nativeContext()
        context.evaluateScript("""
        application.valueForKey=function(key){this.lastError={code:-1743};return null;};
        """)
        XCTAssertTrue(try focusReply(context).contains("permissionDenied"))
        XCTAssertEqual(context.objectForKeyedSubscript("calls")?.toInt32(), 0)
    }

    func testVanishedExactProxyIsTargetUnavailableAndNeverFocuses() throws {
        for nilValue in ["null", "{isNil:function(){return true;}}"] {
            let context = try nativeContext()
            context.evaluateScript("""
            var lookups=0;
            application.terminals.objectWithID=function(id){lookups++;return lookups===1?terminal:\(nilValue);};
            """)
            XCTAssertTrue(try focusReply(context).contains("targetUnavailable"))
            XCTAssertEqual(context.objectForKeyedSubscript("calls")?.toInt32(), 0)
        }
    }

    private func focusReply(_ context: JSContext) throws -> String {
        let request: [String: Any] = ["action": "focus", "terminalID": "quoted\";id", "tty": "/dev/ttys001", "pid": 10]
        let json = String(data: try JSONSerialization.data(withJSONObject: request), encoding: .utf8)!
        return try XCTUnwrap(context.objectForKeyedSubscript("run").call(withArguments: [[json]])?.toString())
    }

    private func nativeContext() throws -> JSContext {
        let context = try XCTUnwrap(JSContext())
        context.evaluateScript("""
        var calls = 0, selected = false, focused = 'other', requestedPID;
        var ObjC = {import: function(){}, unwrap: function(value){return value;}};
        function object(value) { value.valueForKey=function(key){return this[key];}; return value; }
        function array(values) { return {count:values.length,objectAtIndex:function(i){return values[i];},
            objectWithID:function(id){return values.find(function(value){return value.id===id;});}}; }
        var terminal = object({id:'quoted";id',name:'same',workingDirectory:'/same',tty:'/dev/ttys001',pid:100});
        Object.defineProperty(terminal,'focus',{get:function(){calls++;selected=true;focused=terminal.id;}});
        var tab = object({id:'tab',terminals:array([terminal])});
        Object.defineProperty(tab,'selected',{get:function(){return selected;}});
        Object.defineProperty(tab,'focusedTerminal',{get:function(){return object({id:focused,tty:terminal.tty});}});
        var window = object({id:'window',tabs:array([tab]),selectedTab:tab});
        var application = object({isRunning:true,frontmost:true,windows:array([window]),
            terminals:array([terminal]),frontWindow:window});
        var $ = {SBApplication:{applicationWithProcessIdentifier:function(pid){requestedPID=pid;return application;}}};
        """)
        context.evaluateScript(GhosttyCatalog.script)
        return context
    }
}
