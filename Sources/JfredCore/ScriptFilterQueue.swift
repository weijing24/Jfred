import Foundation

/// When a Script Filter runs while the user types, from the object's Run
/// Behaviour settings in Alfred's `info.plist`.
///
/// Alfred 5 stores four keys in the object config. The meaning of each value
/// was read from Alfred's Run Behaviour sheet and its `filterWithQuery:` code:
///
/// - `queuemode`: 1 waits for the previous run to finish, 2 terminates it.
///   Alfred treats every value other than 2 as "wait".
/// - `queuedelaymode`: 0 runs after each character, 1 waits for an automatic
///   delay that follows the user's typing speed, 2 waits a custom delay.
/// - `queuedelaycustom`: the custom delay in tenths of a second, 1...10.
/// - `queuedelayimmediatelyinitially`: the first character of the argument
///   runs at once, whatever the delay.
///
/// Script Filters without any of these keys, such as ones made in Jfred,
/// use `fallback`.
public struct ScriptFilterRunBehaviour: Equatable, Sendable {
    public enum Mode: Equatable, Sendable {
        /// Let the running script finish, then run only the newest query.
        case waitForPrevious
        /// Stop the running script and run the newest query.
        case terminatePrevious
    }

    public enum Delay: Equatable, Sendable {
        case immediate
        /// Follows the user's typing speed; see `TypingCadence`.
        case automatic
        case seconds(TimeInterval)
    }

    public var mode: Mode
    public var delay: Delay
    /// The first query of a session skips the delay.
    public var immediateFirstRun: Bool

    public init(mode: Mode, delay: Delay, immediateFirstRun: Bool) {
        self.mode = mode
        self.delay = delay
        self.immediateFirstRun = immediateFirstRun
    }

    /// Terminate the previous run, run the first query at once and debounce
    /// later keystrokes by 100 ms.
    public static let fallback = ScriptFilterRunBehaviour(mode: .terminatePrevious, delay: .seconds(0.1), immediateFirstRun: true)

    static let configKeys = ["queuemode", "queuedelaymode", "queuedelaycustom", "queuedelayimmediatelyinitially"]

    /// Reads the Run Behaviour keys. A missing key takes Alfred's default for a
    /// new Script Filter: wait, no delay, 300 ms custom delay, first run at once.
    public init(config: [String: WorkflowValue]) {
        guard Self.configKeys.contains(where: { config[$0] != nil }) else {
            self = .fallback
            return
        }
        mode = (config["queuemode"]?.intValue ?? 1) == 2 ? .terminatePrevious : .waitForPrevious
        switch config["queuedelaymode"]?.intValue ?? 0 {
        case ...0:
            delay = .immediate
        case 1:
            delay = .automatic
        default:
            let tenths = min(max(config["queuedelaycustom"]?.intValue ?? 3, 1), 10)
            delay = .seconds(Double(tenths) / 10)
        }
        immediateFirstRun = config["queuedelayimmediatelyinitially"]?.boolValue ?? true
    }

    /// Seconds to wait before a query is queued. `automaticDelay` comes from
    /// `TypingCadence`.
    public func delay(firstQuery: Bool, automaticDelay: TimeInterval) -> TimeInterval {
        if firstQuery && immediateFirstRun { return 0 }
        switch delay {
        case .immediate: return 0
        case .automatic: return automaticDelay
        case .seconds(let seconds): return seconds
        }
    }
}

/// The user's typing speed, for Alfred's "automatic delay after last character
/// typed". Like Alfred, the delay is 1.8 times the mean gap between keys, counting
/// only gaps under 0.8 s, starting from 0.4 s and never above 0.8 s. Gaps under
/// 20 ms are not typing (a query set by the app, or a repeated search) and do
/// not count either.
public struct TypingCadence: Sendable, Equatable {
    public static let initialDelay: TimeInterval = 0.4
    public static let longestGap: TimeInterval = 0.8
    public static let shortestGap: TimeInterval = 0.02
    static let factor = 1.8

    private var sum: TimeInterval
    private var count: Int
    private var last: TimeInterval?
    private var stored: TimeInterval

    public init() {
        stored = Self.initialDelay
        sum = Self.initialDelay
        count = 1
    }

    /// The delay to wait for the user to stop typing.
    public var delay: TimeInterval { min(stored, Self.longestGap) }

    /// Records a keystroke at `time`, in seconds on any monotonic clock.
    public mutating func keystroke(at time: TimeInterval) {
        defer { last = time }
        guard let last else { return }
        let gap = time - last
        guard gap >= Self.shortestGap, gap < Self.longestGap else { return }
        count += 1
        sum += gap
        stored = sum / Double(count) * Self.factor
    }

    /// Starts a new typing session: the gap from the previous session does not
    /// count, and earlier sessions weigh as one sample.
    public mutating func beginSession() {
        last = nil
        sum = stored
        count = 1
    }
}

/// The launcher's Script Filter runs as plain state: the Script Filter being
/// typed into, the run in flight, and a query waiting behind it. At most one
/// script runs at a time. `AppModel` performs the commands this returns.
///
/// A query goes through two stages. `submit` starts its delay; when the delay
/// ends, `fire` queues it. A queued query launches at once, unless a run is in
/// flight and the Script Filter waits for the previous run, in which case it
/// waits and launches when that run finishes. A newer keystroke supersedes a
/// query in either stage.
public struct ScriptFilterQueue<Payload: Sendable>: Sendable {
    public struct Request: Sendable {
        /// Identifies the Script Filter, e.g. "workflowID|inputID".
        public var filter: String
        public var argument: String
        public var behaviour: ScriptFilterRunBehaviour
        /// What `AppModel` needs to launch the run.
        public var payload: Payload

        public init(filter: String, argument: String, behaviour: ScriptFilterRunBehaviour, payload: Payload) {
            self.filter = filter
            self.argument = argument
            self.behaviour = behaviour
            self.payload = payload
        }
    }

    public enum Command: Sendable {
        /// Stop run `id`; its output is no longer wanted.
        case terminate(runID: Int)
        /// Call `fire(ticket:)` after `seconds` (0: right away).
        case wait(seconds: TimeInterval, ticket: Int)
        /// Start run `id` for `request`.
        case launch(runID: Int, request: Request)
    }

    /// What to do with the output of a finished run.
    public enum Outcome: Equatable, Sendable {
        /// The output answers the newest query.
        case current
        /// The output is for an older query, and nothing on screen answers the
        /// newest query yet. Alfred shows such output while the user types.
        case interim
        /// Drop the output, but it may still be cached.
        case stale
        /// The run was terminated or belongs to another Script Filter.
        case unknown
    }

    public private(set) var filter: String?
    /// The run in flight. `sequence` is the ticket of the query it runs.
    public private(set) var running: (id: Int, argument: String, sequence: Int)?
    /// The newest query, once its delay has ended, waiting for `running`.
    public private(set) var waiting: Request?
    private var latest: Request?
    /// The newest query's rows are on screen.
    private var answered = false
    /// The newest query is still in its delay.
    private var delaying = false
    private var ticket = 0
    /// The ticket of the query whose rows are on screen.
    private var shown = 0
    private var nextRunID = 0
    private var firstQuery = true

    public init() {}

    /// True while the newest query is unanswered: it is in its delay, waits
    /// for a run, or runs. A run whose output is only cached does not count.
    public var isBusy: Bool { delaying || waiting != nil || (running != nil && !answered) }

    /// A keystroke produced `request`, and no cached rows answer it.
    public mutating func submit(_ request: Request, automaticDelay: TimeInterval) -> [Command] {
        var commands: [Command] = []
        if request.filter != filter {
            commands += reset()
            filter = request.filter
            firstQuery = true
        }
        ticket += 1
        latest = request
        answered = false
        waiting = nil
        if request.behaviour.mode == .terminatePrevious, let running {
            commands.append(.terminate(runID: running.id))
            self.running = nil
        }
        let delay = request.behaviour.delay(firstQuery: firstQuery, automaticDelay: automaticDelay)
        firstQuery = false
        delaying = true
        commands.append(.wait(seconds: delay, ticket: ticket))
        return commands
    }

    /// Cached rows answered `request`, so nothing needs to run for it. A query
    /// in its delay or waiting is dropped. A run in flight is terminated when
    /// the Script Filter terminates previous runs; otherwise it finishes and its
    /// output is only cached.
    public mutating func answer(_ request: Request) -> [Command] {
        var commands: [Command] = []
        if request.filter != filter {
            commands += reset()
            filter = request.filter
        }
        firstQuery = false
        ticket += 1
        shown = ticket
        latest = request
        answered = true
        delaying = false
        waiting = nil
        if request.behaviour.mode == .terminatePrevious, let running {
            commands.append(.terminate(runID: running.id))
            self.running = nil
        }
        return commands
    }

    /// The delay for `ticket` ended.
    public mutating func fire(ticket fired: Int) -> [Command] {
        guard fired == ticket, delaying, let latest else { return [] }
        delaying = false
        if let running {
            switch latest.behaviour.mode {
            case .waitForPrevious:
                waiting = latest
                return []
            case .terminatePrevious:
                self.running = nil
                return [.terminate(runID: running.id), launch(latest)]
            }
        }
        return [launch(latest)]
    }

    /// Run `id` produced output.
    public mutating func finish(runID id: Int) -> (outcome: Outcome, commands: [Command]) {
        guard let running, running.id == id else { return (.unknown, []) }
        self.running = nil
        let outcome: Outcome
        if !answered, running.argument == latest?.argument {
            // Also covers typing and then deleting back to this argument: the
            // output answers the newest query, so nothing needs to run again.
            outcome = .current
            answered = true
            delaying = false
            waiting = nil
            shown = ticket
        } else if !answered, running.sequence > shown {
            outcome = .interim
            shown = running.sequence
        } else {
            // Older than the rows on screen.
            outcome = .stale
        }
        var commands: [Command] = []
        if let waiting {
            self.waiting = nil
            commands.append(launch(waiting))
        }
        return (outcome, commands)
    }

    /// The query left this Script Filter, or the launcher closed. Terminates
    /// the run in flight and drops waiting queries.
    public mutating func reset() -> [Command] {
        var commands: [Command] = []
        if let running { commands.append(.terminate(runID: running.id)) }
        running = nil
        waiting = nil
        latest = nil
        answered = false
        delaying = false
        filter = nil
        firstQuery = true
        ticket += 1
        // Whatever is on screen now is newer than any run of this session.
        shown = ticket
        return commands
    }

    private mutating func launch(_ request: Request) -> Command {
        nextRunID += 1
        // Only the newest query launches, so its ticket is the current one.
        running = (nextRunID, request.argument, ticket)
        return .launch(runID: nextRunID, request: request)
    }
}
