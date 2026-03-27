import AppKit

class MainWindowController: NSWindowController {
    let monitor = MonitorController()

    // UI elements
    private let pathField = NSTextField()
    private let browseButton = NSButton()
    private let startButton = NSButton()
    private let stopButton = NSButton()
    private let statusLabel = NSTextField()
    private let logView = NSTextView()

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 340),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Pages Monitor"
        window.center()
        self.init(window: window)
        buildUI()
        bindMonitor()
    }

    // MARK: - UI Construction

    private func buildUI() {
        guard let content = window?.contentView else { return }
        content.wantsLayer = true

        // --- Folder label ---
        let folderLabel = makeLabel("Watch folder:")
        folderLabel.frame = NSRect(x: 16, y: 284, width: 100, height: 20)
        content.addSubview(folderLabel)

        // --- Path field ---
        pathField.frame = NSRect(x: 16, y: 258, width: 368, height: 24)
        pathField.placeholderString = "Select a folder to monitor..."
        pathField.bezelStyle = .roundedBezel
        pathField.target = self
        pathField.action = #selector(pathChanged)
        content.addSubview(pathField)

        // --- Browse button ---
        browseButton.frame = NSRect(x: 392, y: 257, width: 92, height: 26)
        browseButton.title = "Browse..."
        browseButton.bezelStyle = .rounded
        browseButton.target = self
        browseButton.action = #selector(browseClicked)
        content.addSubview(browseButton)

        // --- Start button ---
        startButton.frame = NSRect(x: 16, y: 214, width: 160, height: 32)
        startButton.title = "Start"
        startButton.bezelStyle = .rounded
        startButton.isEnabled = false
        startButton.target = self
        startButton.action = #selector(startClicked)
        content.addSubview(startButton)

        // --- Stop button ---
        stopButton.frame = NSRect(x: 184, y: 214, width: 160, height: 32)
        stopButton.title = "Stop"
        stopButton.bezelStyle = .rounded
        stopButton.isEnabled = false
        stopButton.target = self
        stopButton.action = #selector(stopClicked)
        content.addSubview(stopButton)

        // --- Status label ---
        statusLabel.frame = NSRect(x: 16, y: 186, width: 460, height: 20)
        statusLabel.stringValue = "Status: Idle"
        statusLabel.isEditable = false
        statusLabel.isBordered = false
        statusLabel.backgroundColor = .clear
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = NSFont.systemFont(ofSize: 12)
        content.addSubview(statusLabel)

        // --- Log scroll view ---
        let scrollView = NSScrollView(frame: NSRect(x: 16, y: 16, width: 468, height: 162))
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder

        logView.frame = NSRect(x: 0, y: 0, width: 468, height: 162)
        logView.isEditable = false
        logView.isSelectable = true
        logView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        logView.textColor = NSColor(white: 0.85, alpha: 1.0)
        logView.backgroundColor = NSColor(white: 0.08, alpha: 1.0)
        logView.textContainerInset = NSSize(width: 4, height: 4)
        logView.string = "Waiting to start...\n"
        logView.minSize = NSSize(width: 0, height: 162)
        logView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        logView.isVerticallyResizable = true
        logView.isHorizontallyResizable = false
        logView.textContainer?.widthTracksTextView = true
        logView.textContainer?.containerSize = NSSize(width: 468, height: CGFloat.greatestFiniteMagnitude)

        scrollView.documentView = logView
        content.addSubview(scrollView)
    }

    // MARK: - Monitor Binding

    private func bindMonitor() {
        monitor.onOutput = { [weak self] text in
            self?.appendLog(text)
        }
        monitor.onStateChange = { [weak self] state in
            self?.updateUI(for: state)
        }
    }

    // MARK: - Actions

    @objc private func browseClicked(_ sender: Any) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        panel.begin { [weak self] response in
            if response == .OK, let url = panel.url {
                self?.pathField.stringValue = url.path
                self?.updateStartButton()
            }
        }
    }

    @objc private func pathChanged(_ sender: Any) {
        updateStartButton()
    }

    @objc private func startClicked(_ sender: Any) {
        let dir = pathField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !dir.isEmpty else { return }
        monitor.start(directory: dir)
    }

    @objc private func stopClicked(_ sender: Any) {
        monitor.stop()
    }

    // MARK: - UI Helpers

    private func updateStartButton() {
        let dir = pathField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: dir, isDirectory: &isDir)
        startButton.isEnabled = exists && isDir.boolValue && monitor.state != .running
    }

    private func updateUI(for state: MonitorState) {
        switch state {
        case .idle:
            statusLabel.stringValue = "Status: Idle"
            statusLabel.textColor = .secondaryLabelColor
            startButton.isEnabled = true
            stopButton.isEnabled = false
            browseButton.isEnabled = true
        case .running:
            statusLabel.stringValue = "Status: Running..."
            statusLabel.textColor = .systemGreen
            startButton.isEnabled = false
            stopButton.isEnabled = true
            browseButton.isEnabled = false
        case .stopped:
            statusLabel.stringValue = "Status: Stopped"
            statusLabel.textColor = .systemOrange
            updateStartButton()
            stopButton.isEnabled = false
            browseButton.isEnabled = true
        }
    }

    private func appendLog(_ text: String) {
        let storage = logView.textStorage!
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor(white: 0.85, alpha: 1.0)
        ]
        storage.append(NSAttributedString(string: text, attributes: attrs))
        logView.scrollToEndOfDocument(nil)
    }

    private func makeLabel(_ text: String) -> NSTextField {
        let f = NSTextField(labelWithString: text)
        f.font = NSFont.systemFont(ofSize: 12)
        return f
    }
}
