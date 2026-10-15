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
            XCTAssertGreaterThan(timeout, 0); XCTAssertLessThanOrEqual(timeout, 2)
            let request = try JSONSerialization.jsonObject(with: Data(try XCTUnwrap(args.last).utf8))
                as? [String: Any]
            XCTAssertEqual(request?["allowedIDs"] as? [String], ["a"])
            XCTAssertEqual(request?["includeMetadata"] as? Bool, false)
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

    func testSnapshotDeadlineIncludesQueueWaitAndSkipsExpiredQueuedWork() throws {
        let runner = MockProcessRunner(), entered = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0), data = try reply([row("a")])
        var calls = 0
        runner.boundedHandler = { _, _, _ in
            calls += 1
            if calls == 1 { entered.signal(); release.wait() }
            return data
        }
        let catalog = GhosttyCatalog(processRunner: runner, application: { self.app })
        let refreshed = expectation(description: "Blocking refresh finished")
        catalog.refresh { _ in refreshed.fulfill() }
        XCTAssertEqual(entered.wait(timeout: .now() + 1), .success)
        defer { release.signal() }
        // The blocker outlives the snapshot's complete two-second budget.
        DispatchQueue.global().asyncAfter(deadline: .now() + 2.3) { release.signal() }
        let start = DispatchTime.now().uptimeNanoseconds
        XCTAssertThrowsError(try catalog.snapshot()) { error in
            guard case ProcessRunnerError.processTimedOut = error else { return XCTFail("\(error)") }
        }
        XCTAssertLessThan(Double(DispatchTime.now().uptimeNanoseconds - start) / 1e9, 2.2)
        wait(for: [refreshed], timeout: 1)
        _ = try catalog.snapshot()
        XCTAssertEqual(calls, 2, "Expired queued snapshot must not issue a native request")
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

    func testScriptBatchesMetadataAndPreservesNativeOrderForManySurfaces() throws {
        let context = try nativeContext()
        context.evaluateScript("""
        var individualReads=0, many=[];
        for(var i=0;i<37;i++) {
            var item=object({id:'surface-'+i,name:'same',workingDirectory:'/same',tty:'/dev/ttys'+i,pid:100+i});
            item.valueForKey=function(key){individualReads++;return this[key];};
            many.push(item);
        }
        application.terminals=array(many); tab.terminals=array(many);
        """)
        let rows = try GhosttyCatalog.decode(scriptReply(context), application: app)
        XCTAssertEqual(rows.map(\.id.terminalID), (0..<37).map { "surface-\($0)" })
        XCTAssertEqual(rows.last?.foregroundPID, 136)
        XCTAssertEqual(context.objectForKeyedSubscript("individualReads")?.toInt32(), 0)
        XCTAssertLessThanOrEqual(context.objectForKeyedSubscript("columnReads").toInt32(), 12)
    }

    func testMappingSnapshotSkipsDisplayReadsAndKeepsFreshNativeBinding() throws {
        let context = try nativeContext()
        context.evaluateScript("window.id='moved-window'; tab.id='moved-tab'; terminal.pid=101;")
        let surface = try XCTUnwrap(GhosttyCatalog.decode(
            scriptReply(context, includeMetadata: false), application: app).first)
        XCTAssertEqual(surface.id.terminalID, "quoted\";id")
        XCTAssertEqual(surface.windowID, "moved-window")
        XCTAssertEqual(surface.tabID, "moved-tab")
        XCTAssertEqual(surface.tty, "/dev/ttys001")
        XCTAssertEqual(surface.foregroundPID, 101)
        XCTAssertNil(surface.mappingIssue)
        XCTAssertNil(surface.title)
        XCTAssertNil(surface.directory)
        XCTAssertNil(surface.tabSelected)
        let keys = try XCTUnwrap(context.objectForKeyedSubscript("columnKeys").toArray() as? [String])
        XCTAssertFalse(keys.contains("name"))
        XCTAssertFalse(keys.contains("workingDirectory"))
        XCTAssertFalse(keys.contains("selected"))
        XCTAssertEqual(keys.filter { $0 == "id" }.count, 5)
        XCTAssertTrue(keys.contains("tty"))
        XCTAssertTrue(keys.contains("pid"))

        let full = try nativeContext()
        let displayed = try XCTUnwrap(GhosttyCatalog.decode(scriptReply(full), application: app).first)
        XCTAssertEqual(displayed.title, "same")
        XCTAssertEqual(displayed.directory, "/same")
        XCTAssertEqual(displayed.tabSelected, false)
    }

    func testMappingSnapshotRejectsDuplicateIDsAndRetainsAmbiguousTTYCoverage() throws {
        let duplicate = try nativeContext()
        duplicate.evaluateScript("application.terminals=array([terminal,terminal]);")
        XCTAssertTrue(String(decoding: try scriptReply(duplicate, includeMetadata: false),
                             as: UTF8.self).contains("nativeUnavailable"))
        let ambiguous = try nativeContext()
        ambiguous.evaluateScript("""
        var second=object({id:'other',tty:terminal.tty,pid:101});
        application.terminals=array([terminal,second]); tab.terminals=application.terminals;
        """)
        let rows = try GhosttyCatalog.decode(scriptReply(ambiguous, includeMetadata: false), application: app)
        XCTAssertEqual(rows.count, 2)
        XCTAssertTrue(rows.allSatisfy { $0.mappingIssue == .ambiguousTTY })
    }

    func testScriptRejectsChangedColumnIdentityAndPreservesMissingCoverage() throws {
        for includeMetadata in [true, false] {
            let changed = try nativeContext()
            changed.evaluateScript("""
            var original=application.terminals.arrayByApplyingSelector, idReads=0;
            application.terminals.arrayByApplyingSelector=function(key){
                var values=original(key); return key==='id' && ++idReads===2 ? ['replacement'] : values;
            };
            """)
            XCTAssertTrue(String(decoding: try scriptReply(changed, includeMetadata: includeMetadata),
                                 as: UTF8.self).contains("nativeUnavailable"))
            let missing = try nativeContext()
            missing.evaluateScript("""
            var original=application.terminals.arrayByApplyingSelector;
            application.terminals.arrayByApplyingSelector=function(key){return key==='tty'?[]:original(key);};
            """)
            let rows = try GhosttyCatalog.decode(scriptReply(missing, includeMetadata: includeMetadata), application: app)
            XCTAssertEqual(rows.first?.mappingIssue, .missingTTY)
            XCTAssertEqual(rows.first?.title, includeMetadata ? "same" : nil)
            let denied = try nativeContext()
            denied.evaluateScript("""
            var original=application.terminals.arrayByApplyingSelector;
            application.terminals.arrayByApplyingSelector=function(key){
                var values=original(key); application.lastError=key==='tty'?{code:-1743}:null; return values;
            };
            """)
            XCTAssertTrue(String(decoding: try scriptReply(denied, includeMetadata: includeMetadata),
                                 as: UTF8.self).contains("permissionDenied"))
        }
    }

    private func scriptReply(_ context: JSContext, includeMetadata: Bool = true) throws -> Data {
        let request: [String: Any] = ["action": "enumerate", "pid": 10, "includeMetadata": includeMetadata]
        let data = try JSONSerialization.data(withJSONObject: request)
        let text = try XCTUnwrap(context.objectForKeyedSubscript("run")
            .call(withArguments: [[String(decoding: data, as: UTF8.self)]])?.toString())
        XCTAssertNil(context.exception)
        return Data(text.utf8)
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
            application.terminals.objectWithID=function(id){return \(nilValue);};
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
        var calls = 0, selected = false, focused = 'other', requestedPID, columnReads=0, columnKeys=[];
        var ObjC = {import: function(){}, unwrap: function(value){return value;},deepUnwrap:function(value){return value;}};
        function object(value) { value.valueForKey=function(key){return this[key];}; return value; }
        function array(values) { return {count:values.length,objectAtIndex:function(i){return values[i];},
            arrayByApplyingSelector:function(key){columnReads++;columnKeys.push(key);return values.map(function(value){return value[key];});},
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
