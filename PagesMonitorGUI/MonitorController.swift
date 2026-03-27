import Foundation

enum MonitorState {
    case idle, running, stopped
}

class MonitorController {
    private var process: Process?
    private var pipe: Pipe?

    var state: MonitorState = .idle
    var onStateChange: ((MonitorState) -> Void)?
    var onOutput: ((String) -> Void)?

    func start(directory: String) {
        guard state != .running else { return }

        // Preflight: check fswatch is available
        let fswatchPaths = ["/opt/homebrew/bin/fswatch", "/usr/local/bin/fswatch"]
        guard fswatchPaths.contains(where: { FileManager.default.fileExists(atPath: $0) }) else {
            emit("ERROR: fswatch not found.\nInstall it with:  brew install fswatch\n")
            return
        }

        guard let scriptURL = Bundle.main.resourceURL?.appendingPathComponent("pages_to_docx_watcher.sh"),
              FileManager.default.fileExists(atPath: scriptURL.path) else {
            emit("ERROR: pages_to_docx_watcher.sh not found in app bundle.\n")
            return
        }

        let proc = Process()
        let p = Pipe()
        self.process = proc
        self.pipe = p

        proc.executableURL = URL(fileURLWithPath: "/bin/bash")
        proc.arguments = [scriptURL.path, directory]
        proc.environment = [
            "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
            "HOME": NSHomeDirectory(),
            "TERM": "dumb"
        ]
        proc.standardOutput = p
        proc.standardError = p

        p.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async { self?.emit(text) }
        }

        proc.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.p?.fileHandleForReading.readabilityHandler = nil
                if self?.state == .running {
                    self?.setState(.stopped)
                    self?.emit("--- Monitoring stopped ---\n")
                }
            }
        }

        do {
            try proc.run()
            setState(.running)
            emit("Started monitoring: \(directory)\n")
        } catch {
            emit("ERROR: Failed to start process: \(error.localizedDescription)\n")
        }
    }

    func stop() {
        guard let proc = process, proc.isRunning else {
            if state != .idle { setState(.stopped) }
            return
        }
        // Kill the entire process group so fswatch child is also terminated
        kill(-proc.processIdentifier, SIGTERM)
        proc.terminate()
        pipe?.fileHandleForReading.readabilityHandler = nil
        setState(.stopped)
        emit("--- Monitoring stopped ---\n")
    }

    // MARK: - Private

    private var p: Pipe? { return pipe }

    private func emit(_ text: String) {
        onOutput?(text)
    }

    private func setState(_ newState: MonitorState) {
        state = newState
        onStateChange?(newState)
    }
}
