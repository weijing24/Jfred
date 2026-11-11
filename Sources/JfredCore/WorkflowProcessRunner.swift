import Foundation

public final class ProcessWorkflowRunner: WorkflowScriptRunning, @unchecked Sendable {
    public init() {}

    /// Seconds a script may run before it is terminated.
    public static let timeout: TimeInterval = 20

    /// Runs the script on a dispatch thread, not the Swift concurrency pool: the
    /// wait blocks for up to `timeout`. Cancelling the calling task terminates
    /// the script and every process it started, and returns at once with
    /// `WorkflowScriptOutput.cancelledError`.
    public func run(_ request: WorkflowScriptRequest) async -> WorkflowScriptOutput {
        let handle = ScriptProcessHandle()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    continuation.resume(returning: Self.execute(request, handle: handle))
                }
            }
        } onCancel: {
            handle.cancel()
        }
    }

    private static func execute(_ request: WorkflowScriptRequest, handle: ScriptProcessHandle) -> WorkflowScriptOutput {
        guard !handle.isCancelled else { return .cancelled }
        let fileManager = FileManager.default
        let cache = request.environment["alfred_workflow_cache"].map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? fileManager.temporaryDirectory.appendingPathComponent("JfredWorkflowCache", isDirectory: true)
        let data = request.environment["alfred_workflow_data"].map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? fileManager.temporaryDirectory.appendingPathComponent("JfredWorkflowData", isDirectory: true)
        try? fileManager.createDirectory(at: cache, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: data, withIntermediateDirectories: true)

        var temporaryScript: URL?
        defer {
            if let temporaryScript { try? fileManager.removeItem(at: temporaryScript) }
        }

        let executable: String
        var arguments: [String] = []
        if !request.sourceFile.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            var path = (request.sourceFile as NSString).expandingTildeInPath
            if !path.hasPrefix("/") {
                path = request.directory.appendingPathComponent(path).path
            }
            guard fileManager.fileExists(atPath: path) else {
                return WorkflowScriptOutput(error: "Script file not found: \(path)")
            }
            let resolved = executableForScriptFile(path, language: request.language)
            executable = resolved.executable
            if resolved.executable == path {
                arguments = request.arguments
            } else {
                arguments = resolved.arguments + [path] + request.arguments
            }
        } else {
            let source = request.source
            guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return WorkflowScriptOutput(error: "Script is empty")
            }
            let suffix = fileSuffix(for: request.language)
            let url = cache.appendingPathComponent("jfred-\(request.objectID.uuidString)-\(UUID().uuidString).\(suffix)")
            do {
                try source.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                return WorkflowScriptOutput(error: "Could not stage script: \(error.localizedDescription)")
            }
            temporaryScript = url
            switch request.language {
            case .external:
                if source.hasPrefix("#!") {
                    try? fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
                    executable = url.path
                } else {
                    executable = "/bin/bash"
                    arguments = [url.path]
                }
            case .osascript:
                executable = "/usr/bin/osascript"
                arguments = [url.path]
            case .swift:
                executable = "/usr/bin/swift"
                arguments = [url.path]
            case .php:
                executable = "/usr/bin/php"
                arguments = [url.path]
            case .ruby:
                executable = "/usr/bin/ruby"
                arguments = [url.path]
            case .python:
                let python3 = "/usr/bin/python3"
                executable = fileManager.isExecutableFile(atPath: python3) ? python3 : "/usr/bin/python"
                arguments = [url.path]
            case .perl:
                executable = "/usr/bin/perl"
                arguments = [url.path]
            case .bash:
                executable = "/bin/bash"
                arguments = [url.path]
            case .zsh:
                executable = "/bin/zsh"
                arguments = [url.path]
            }
        }
        if request.sourceFile.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            arguments += request.arguments
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = request.directory
        process.environment = request.environment
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        let outBuffer = PipeBuffer()
        let errBuffer = PipeBuffer()
        stdout.fileHandleForReading.readabilityHandler = { handle in
            outBuffer.append(handle.availableData)
        }
        stderr.fileHandleForReading.readabilityHandler = { handle in
            errBuffer.append(handle.availableData)
        }
        let group = DispatchGroup()
        group.enter()
        process.terminationHandler = { _ in group.leave() }
        switch handle.launch(process) {
        case .launched:
            break
        case .cancelled:
            stdout.fileHandleForReading.readabilityHandler = nil
            stderr.fileHandleForReading.readabilityHandler = nil
            return .cancelled
        case .failed(let error):
            stdout.fileHandleForReading.readabilityHandler = nil
            stderr.fileHandleForReading.readabilityHandler = nil
            return WorkflowScriptOutput(error: "Could not launch \(executable): \(error.localizedDescription)")
        }
        var timedOut = false
        if group.wait(timeout: .now() + Self.timeout) == .timedOut {
            timedOut = true
            handle.terminate()
            _ = group.wait(timeout: .now() + 1)
        }
        stdout.fileHandleForReading.readabilityHandler = nil
        stderr.fileHandleForReading.readabilityHandler = nil
        if handle.isCancelled {
            // Do not read to the end: a process that ignored SIGTERM, or one that
            // left the process tree, may hold the pipe open.
            return .cancelled
        }
        // The script has exited, but a process it left in the background may
        // still hold the pipes open. Read what is there, waiting at most
        // `drainTimeout` for the end of the output.
        let deadline = DispatchTime.now() + (timedOut ? 0 : Self.drainTimeout)
        outBuffer.append(Self.drain(stdout.fileHandleForReading, until: deadline))
        errBuffer.append(Self.drain(stderr.fileHandleForReading, until: deadline))
        let status = timedOut ? -1 : process.terminationStatus
        return WorkflowScriptOutput(
            stdout: outBuffer.text,
            stderr: errBuffer.text,
            status: status,
            error: timedOut ? "Script timed out after \(Int(Self.timeout)) seconds" : nil
        )
    }

    /// Seconds to wait for the end of the output after the script exits.
    static let drainTimeout: TimeInterval = 1

    /// Reads a pipe until its end or `deadline`, whichever comes first. After
    /// the deadline, only data already buffered is read.
    static func drain(_ handle: FileHandle, until deadline: DispatchTime) -> Data {
        let descriptor = handle.fileDescriptor
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 65_536)
        while data.count < 2_000_000 {
            let now = DispatchTime.now().uptimeNanoseconds
            let remaining = deadline.uptimeNanoseconds > now ? (deadline.uptimeNanoseconds - now) / 1_000_000 : 0
            var poller = pollfd(fd: descriptor, events: Int16(POLLIN), revents: 0)
            guard poll(&poller, 1, Int32(min(remaining, 60_000))) > 0 else { break }
            let count = read(descriptor, &buffer, buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }

    private static func executableForScriptFile(_ path: String, language: WorkflowScriptLanguage) -> (executable: String, arguments: [String]) {
        if FileManager.default.isExecutableFile(atPath: path) {
            if let first = try? String(contentsOfFile: path, encoding: .utf8).split(separator: "\n", maxSplits: 1).first,
               first.hasPrefix("#!") {
                return (path, [])
            }
        }
        switch language {
        case .bash, .external: return ("/bin/bash", [])
        case .zsh: return ("/bin/zsh", [])
        case .php: return ("/usr/bin/php", [])
        case .ruby: return ("/usr/bin/ruby", [])
        case .python: return ("/usr/bin/python3", [])
        case .perl: return ("/usr/bin/perl", [])
        case .osascript: return ("/usr/bin/osascript", [])
        case .swift: return ("/usr/bin/swift", [])
        }
    }

    private static func fileSuffix(for language: WorkflowScriptLanguage) -> String {
        switch language {
        case .bash: return "sh"
        case .zsh: return "zsh"
        case .php: return "php"
        case .ruby: return "rb"
        case .python: return "py"
        case .perl: return "pl"
        case .osascript: return "applescript"
        case .swift: return "swift"
        case .external: return "sh"
        }
    }
}

extension WorkflowScriptOutput {
    public static let cancelledError = "Script was cancelled"

    static let cancelled = WorkflowScriptOutput(status: -1, error: cancelledError)

    /// The run was cancelled before the script finished.
    public var wasCancelled: Bool { error == Self.cancelledError }
}

/// The process behind one script run, shared between the thread that waits for
/// it and the task cancellation handler.
final class ScriptProcessHandle: @unchecked Sendable {
    enum Launch {
        case launched
        case cancelled
        case failed(Error)
    }

    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    /// Starts `process` unless the run was already cancelled. Holding the lock
    /// while starting means `cancel()` either prevents the launch or sees the
    /// process.
    func launch(_ process: Process) -> Launch {
        lock.lock()
        defer { lock.unlock() }
        guard !cancelled else { return .cancelled }
        do {
            try process.run()
        } catch {
            return .failed(error)
        }
        self.process = process
        return .launched
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let process = self.process
        lock.unlock()
        if let process { Self.terminateTree(process) }
    }

    func terminate() {
        lock.lock()
        let process = self.process
        lock.unlock()
        if let process { Self.terminateTree(process) }
    }

    /// Sends SIGTERM to the script and to every process below it, then
    /// SIGKILL to any of them still running a second later. An inline script
    /// runs under /bin/bash, which does not pass SIGTERM on to a command it is
    /// waiting for, such as `python3 filter.py`; that command would keep
    /// running and keep the output pipe open.
    static func terminateTree(_ process: Process) {
        guard process.isRunning else { return }
        let root = process.processIdentifier
        // Collect descendants before signalling: once a parent exits, its
        // children move to launchd and can no longer be found from here.
        let pids = [root] + Self.descendants(of: root)
        for pid in pids {
            kill(pid, SIGTERM)
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1) {
            // The root is still our child until it is reaped, so its pid cannot
            // have been reused; the descendants were found a second ago.
            guard process.isRunning || pids.count > 1 else { return }
            for pid in pids where kill(pid, 0) == 0 {
                kill(pid, SIGKILL)
            }
        }
    }

    static func descendants(of root: pid_t) -> [pid_t] {
        var found: [pid_t] = []
        var queue: [pid_t] = [root]
        while let parent = queue.popLast(), found.count < 512 {
            var children = [pid_t](repeating: 0, count: 128)
            let count = proc_listchildpids(parent, &children, Int32(MemoryLayout<pid_t>.stride * children.count))
            guard count > 0 else { continue }
            for child in children.prefix(Int(count)) where child > 0 {
                found.append(child)
                queue.append(child)
            }
        }
        return found
    }
}

private final class PipeBuffer: @unchecked Sendable {
    private var data = Data()
    private let lock = NSLock()

    func append(_ chunk: Data) {
        guard !chunk.isEmpty else { return }
        lock.lock()
        if data.count < 2_000_000 { data.append(chunk) }
        lock.unlock()
    }

    var text: String {
        lock.lock()
        defer { lock.unlock() }
        return String(data: data, encoding: .utf8) ?? ""
    }
}
