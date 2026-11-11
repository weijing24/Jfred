import Foundation
import Testing
@testable import JfredCore

struct ScriptFilterRunBehaviourTests {
    @Test func objectsWithoutQueueKeysUseTheFallback() {
        let behaviour = ScriptFilterRunBehaviour(config: ["keyword": .string("wf"), "type": .integer(0)])
        #expect(behaviour == .fallback)
        #expect(behaviour.mode == .terminatePrevious)
        #expect(behaviour.delay == .seconds(0.1))
        #expect(behaviour.immediateFirstRun)
    }

    @Test func alfredDefaultsWaitAndRunEveryCharacter() {
        // The values Alfred 5 writes for a new Script Filter.
        let behaviour = ScriptFilterRunBehaviour(config: [
            "queuemode": .integer(1),
            "queuedelaymode": .integer(0),
            "queuedelaycustom": .integer(3),
            "queuedelayimmediatelyinitially": .boolean(true),
        ])
        #expect(behaviour.mode == .waitForPrevious)
        #expect(behaviour.delay == .immediate)
        #expect(behaviour.immediateFirstRun)
    }

    @Test func terminateWithCustomDelayInTenthsOfASecond() {
        let behaviour = ScriptFilterRunBehaviour(config: [
            "queuemode": .integer(2),
            "queuedelaymode": .integer(2),
            "queuedelaycustom": .integer(3),
            "queuedelayimmediatelyinitially": .boolean(false),
        ])
        #expect(behaviour.mode == .terminatePrevious)
        #expect(behaviour.delay == .seconds(0.3))
        #expect(!behaviour.immediateFirstRun)
    }

    @Test func customDelayIsClampedLikeAlfredsMenu() {
        let low = ScriptFilterRunBehaviour(config: ["queuedelaymode": .integer(2), "queuedelaycustom": .integer(0)])
        let high = ScriptFilterRunBehaviour(config: ["queuedelaymode": .integer(2), "queuedelaycustom": .integer(25)])
        #expect(low.delay == .seconds(0.1))
        #expect(high.delay == .seconds(1.0))
    }

    @Test func automaticDelayAndPartialKeys() {
        let behaviour = ScriptFilterRunBehaviour(config: ["queuedelaymode": .integer(1)])
        #expect(behaviour.delay == .automatic)
        // Missing keys take Alfred's defaults, not the fallback.
        #expect(behaviour.mode == .waitForPrevious)
        #expect(behaviour.immediateFirstRun)
        // Any queue mode other than 2 waits, as in Alfred.
        #expect(ScriptFilterRunBehaviour(config: ["queuemode": .integer(0)]).mode == .waitForPrevious)
    }

    @Test func delayForFirstAndLaterQueries() {
        let custom = ScriptFilterRunBehaviour(mode: .terminatePrevious, delay: .seconds(0.5), immediateFirstRun: true)
        #expect(custom.delay(firstQuery: true, automaticDelay: 0.4) == 0)
        #expect(custom.delay(firstQuery: false, automaticDelay: 0.4) == 0.5)

        let notInitially = ScriptFilterRunBehaviour(mode: .terminatePrevious, delay: .seconds(0.5), immediateFirstRun: false)
        #expect(notInitially.delay(firstQuery: true, automaticDelay: 0.4) == 0.5)

        let automatic = ScriptFilterRunBehaviour(mode: .waitForPrevious, delay: .automatic, immediateFirstRun: false)
        #expect(automatic.delay(firstQuery: false, automaticDelay: 0.27) == 0.27)

        let immediate = ScriptFilterRunBehaviour(mode: .waitForPrevious, delay: .immediate, immediateFirstRun: false)
        #expect(immediate.delay(firstQuery: false, automaticDelay: 0.4) == 0)
    }
}

struct TypingCadenceTests {
    @Test func startsAtFourHundredMilliseconds() {
        #expect(TypingCadence().delay == 0.4)
    }

    @Test func followsTheMeanGapBetweenKeys() {
        var cadence = TypingCadence()
        cadence.keystroke(at: 10.0)
        cadence.keystroke(at: 10.1)
        // Mean of the 0.4 seed and a 0.1 gap, times 1.8.
        #expect(abs(cadence.delay - 0.45) < 1e-9)
        cadence.keystroke(at: 10.2)
        #expect(abs(cadence.delay - 0.36) < 1e-9)
    }

    @Test func ignoresPausesAndCapsTheDelay() {
        var cadence = TypingCadence()
        cadence.keystroke(at: 0)
        cadence.keystroke(at: 5)
        #expect(cadence.delay == 0.4)
        cadence.keystroke(at: 5.7)
        cadence.keystroke(at: 6.4)
        #expect(cadence.delay == TypingCadence.longestGap)
    }

    @Test func ignoresGapsTooShortToBeTyping() {
        var cadence = TypingCadence()
        cadence.keystroke(at: 1.0)
        cadence.keystroke(at: 1.001)
        cadence.keystroke(at: 1.002)
        #expect(cadence.delay == 0.4)
    }

    @Test func aNewSessionDoesNotCountTheGapSinceTheLastKey() {
        var cadence = TypingCadence()
        cadence.keystroke(at: 1.0)
        cadence.beginSession()
        cadence.keystroke(at: 1.1)
        #expect(cadence.delay == 0.4)
    }
}

struct ScriptFilterQueueTests {
    typealias Queue = ScriptFilterQueue<String>

    static let terminate = ScriptFilterRunBehaviour(mode: .terminatePrevious, delay: .seconds(0.1), immediateFirstRun: true)
    static let wait = ScriptFilterRunBehaviour(mode: .waitForPrevious, delay: .immediate, immediateFirstRun: true)

    func request(_ argument: String, filter: String = "wf|sf", behaviour: ScriptFilterRunBehaviour = terminate) -> Queue.Request {
        Queue.Request(filter: filter, argument: argument, behaviour: behaviour, payload: argument)
    }

    /// Submits and, when the delay is zero, fires at once, as AppModel does.
    /// A delay is logged as "wait"; `lastTicket` gets its ticket.
    func type(_ argument: String, into queue: inout Queue, behaviour: ScriptFilterRunBehaviour = terminate, filter: String = "wf|sf") -> [String] {
        var ticket = 0
        return type(argument, into: &queue, behaviour: behaviour, filter: filter, lastTicket: &ticket)
    }

    func type(_ argument: String, into queue: inout Queue, behaviour: ScriptFilterRunBehaviour = terminate, filter: String = "wf|sf", lastTicket: inout Int) -> [String] {
        var log: [String] = []
        var pending = queue.submit(request(argument, filter: filter, behaviour: behaviour), automaticDelay: 0.4)
        while !pending.isEmpty {
            let command = pending.removeFirst()
            switch command {
            case .terminate(let id): log.append("terminate \(id)")
            case .launch(let id, let request): log.append("launch \(id) \(request.argument)")
            case .wait(let seconds, let ticket):
                if seconds == 0 {
                    pending += queue.fire(ticket: ticket)
                } else {
                    log.append("wait \(seconds)")
                    lastTicket = ticket
                }
            }
        }
        return log
    }

    func describe(_ commands: [Queue.Command]) -> [String] {
        commands.map { command in
            switch command {
            case .terminate(let id): return "terminate \(id)"
            case .launch(let id, let request): return "launch \(id) \(request.argument)"
            case .wait(let seconds, _): return "wait \(seconds)"
            }
        }
    }

    @Test func firstQueryRunsAtOnceAndLaterOnesAreDebounced() {
        var queue = Queue()
        #expect(type("a", into: &queue) == ["launch 1 a"])
        #expect(queue.isBusy)
        // The next keystroke terminates the run and waits 100 ms.
        var second = 0
        #expect(type("ab", into: &queue, lastTicket: &second) == ["terminate 1", "wait 0.1"])
        #expect(queue.running == nil)
        #expect(queue.isBusy)
        // A third keystroke inside the delay supersedes the second.
        var third = 0
        #expect(type("abc", into: &queue, lastTicket: &third) == ["wait 0.1"])
        #expect(describe(queue.fire(ticket: second)).isEmpty)
        #expect(describe(queue.fire(ticket: third)) == ["launch 2 abc"])
        #expect(queue.finish(runID: 2).outcome == .current)
        #expect(!queue.isBusy)
    }

    @Test func terminatedRunsAreUnknownWhenTheyReturn() {
        var queue = Queue()
        _ = type("a", into: &queue)
        _ = type("ab", into: &queue)
        let finished = queue.finish(runID: 1)
        #expect(finished.outcome == .unknown)
        #expect(finished.commands.isEmpty)
    }

    @Test func waitModeKeepsOneRunAndOnlyTheNewestQueryWaits() {
        var queue = Queue()
        #expect(type("t", into: &queue, behaviour: Self.wait) == ["launch 1 t"])
        // Typing while the script runs neither terminates it nor starts another.
        #expect(type("ts", into: &queue, behaviour: Self.wait).isEmpty)
        #expect(type("ts 1", into: &queue, behaviour: Self.wait).isEmpty)
        #expect(queue.waiting?.argument == "ts 1")
        // The first run's rows are shown while the newest query runs.
        let finished = queue.finish(runID: 1)
        #expect(finished.outcome == .interim)
        #expect(describe(finished.commands) == ["launch 2 ts 1"])
        #expect(queue.isBusy)
        #expect(queue.finish(runID: 2).outcome == .current)
        #expect(!queue.isBusy)
    }

    @Test func outputForAnArgumentTypedAgainIsCurrent() {
        var queue = Queue()
        _ = type("a", into: &queue, behaviour: Self.wait)
        _ = type("ab", into: &queue, behaviour: Self.wait)
        _ = type("a", into: &queue, behaviour: Self.wait)
        let finished = queue.finish(runID: 1)
        #expect(finished.outcome == .current)
        #expect(finished.commands.isEmpty)
        #expect(!queue.isBusy)
    }

    @Test func cachedRowsAnswerTheQuery() {
        var queue = Queue()
        _ = type("a", into: &queue)
        // Terminate mode: the run in flight is no longer needed.
        #expect(describe(queue.answer(request("b"))) == ["terminate 1"])
        #expect(!queue.isBusy)

        var waiting = Queue()
        _ = type("a", into: &waiting, behaviour: Self.wait)
        // Wait mode lets the run finish; its output is cached, not shown, and
        // the launcher does not look busy for it.
        #expect(waiting.answer(request("b", behaviour: Self.wait)).isEmpty)
        #expect(!waiting.isBusy)
        #expect(waiting.finish(runID: 1).outcome == .stale)
    }

    @Test func olderOutputNeverReplacesNewerRows() {
        var queue = Queue()
        _ = type("a", into: &queue, behaviour: Self.wait)
        // "ab" is answered from the cache, then "abc" needs a run.
        _ = queue.answer(request("ab", behaviour: Self.wait))
        #expect(type("abc", into: &queue, behaviour: Self.wait).isEmpty)
        #expect(queue.isBusy)
        let finished = queue.finish(runID: 1)
        #expect(finished.outcome == .stale)
        #expect(describe(finished.commands) == ["launch 2 abc"])
        #expect(queue.finish(runID: 2).outcome == .current)
    }

    @Test func anAnswerDropsADelayedQuery() {
        var queue = Queue()
        _ = type("a", into: &queue)
        _ = queue.finish(runID: 1)
        var ticket = 0
        #expect(type("ab", into: &queue, lastTicket: &ticket) == ["wait 0.1"])
        _ = queue.answer(request("a"))
        #expect(describe(queue.fire(ticket: ticket)).isEmpty)
        #expect(!queue.isBusy)
    }

    @Test func switchingScriptFiltersTerminatesTheRunAndStartsANewSession() {
        var queue = Queue()
        _ = type("a", into: &queue, behaviour: Self.wait, filter: "wf|one")
        // A different Script Filter terminates even a waiting-mode run, and its
        // first query runs at once.
        #expect(type("x", into: &queue, filter: "wf|two") == ["terminate 1", "launch 2 x"])
        #expect(queue.finish(runID: 1).outcome == .unknown)
    }

    @Test func resetTerminatesAndDropsEverything() {
        var queue = Queue()
        _ = type("a", into: &queue, behaviour: Self.wait)
        _ = type("ab", into: &queue, behaviour: Self.wait)
        #expect(describe(queue.reset()) == ["terminate 1"])
        #expect(!queue.isBusy)
        #expect(queue.waiting == nil)
        #expect(queue.finish(runID: 1).outcome == .unknown)
        // After a reset the next query is a new session and runs at once.
        #expect(type("a", into: &queue) == ["launch 2 a"])
    }

    @Test func customDelayAppliesToTheFirstQueryWhenNotImmediate() {
        let behaviour = ScriptFilterRunBehaviour(mode: .terminatePrevious, delay: .seconds(0.3), immediateFirstRun: false)
        var queue = Queue()
        var ticket = 0
        #expect(type("a", into: &queue, behaviour: behaviour, lastTicket: &ticket) == ["wait 0.3"])
        #expect(describe(queue.fire(ticket: ticket)) == ["launch 1 a"])
    }
}

struct ProcessRunnerCancellationTests {
    func request(_ source: String) -> WorkflowScriptRequest {
        WorkflowScriptRequest(
            workflowID: UUID(),
            objectID: UUID(),
            bundleID: "com.example.cancel",
            workflowName: "Cancel",
            workflowVersion: "1.0",
            keyword: "c",
            language: .bash,
            source: source,
            sourceFile: "",
            argumentMode: .argv,
            escaping: 0,
            query: "",
            arguments: [],
            variables: [:],
            directory: URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true),
            environment: [
                "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
                "alfred_workflow_cache": NSTemporaryDirectory() + "jfred-runner-test",
            ]
        )
    }

    @Test func cancellingTerminatesTheScriptAndItsChildren() async throws {
        let marker = NSTemporaryDirectory() + "jfred-cancel-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: marker) }
        // bash waits for `sleep`, which would keep running if only bash were
        // terminated; the child writes its pid first so the test can check it.
        let source = "/bin/sleep 30 &\necho $! > '\(marker)'\nwait"
        let started = Date()
        let task = Task { await ProcessWorkflowRunner().run(request(source)) }
        var childPID: pid_t?
        for _ in 0..<200 {
            if let text = try? String(contentsOfFile: marker, encoding: .utf8),
               let pid = pid_t(text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                childPID = pid
                break
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        let pid = try #require(childPID)
        task.cancel()
        let output = await task.value
        #expect(output.wasCancelled)
        #expect(Date().timeIntervalSince(started) < 10)
        var exited = false
        for _ in 0..<100 {
            if kill(pid, 0) != 0 { exited = true; break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(exited)
    }

    @Test func aBackgroundChildHoldingTheOutputDoesNotHangTheRun() async {
        let started = Date()
        // The background sleep inherits stdout and keeps the pipe open after
        // the script exits.
        let output = await ProcessWorkflowRunner().run(request("echo hello\n/bin/sleep 4 &\n"))
        #expect(output.stdout.contains("hello"))
        #expect(output.isSuccess)
        #expect(Date().timeIntervalSince(started) < 3)
    }

    @Test func cancellingBeforeLaunchDoesNotStartTheScript() async {
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return await ProcessWorkflowRunner().run(request("echo hi"))
        }
        let output = await task.value
        #expect(output.wasCancelled)
        #expect(output.stdout.isEmpty)
    }
}
