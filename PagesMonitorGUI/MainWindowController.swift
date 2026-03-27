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

    // Path autocomplete
    private var completionPanel: NSPanel?
    private let completionTable = NSTableView()
    private let completionScrollView = NSScrollView()
    private var completions: [String] = []

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
        setupCompletionPanel()
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
        pathField.delegate = self
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

    // MARK: - Completion Panel Setup

    private func setupCompletionPanel() {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("path"))
        column.isEditable = false
        completionTable.addTableColumn(column)
        completionTable.headerView = nil
        completionTable.dataSource = self
        completionTable.delegate = self
        completionTable.target = self
        completionTable.action = #selector(completionClicked)
        completionTable.rowHeight = 22
        completionTable.selectionHighlightStyle = .regular
        completionTable.usesAlternatingRowBackgroundColors = false

        completionScrollView.documentView = completionTable
        completionScrollView.hasVerticalScroller = true
        completionScrollView.autohidesScrollers = true
        completionScrollView.borderType = .noBorder

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 368, height: 0),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.backgroundColor = NSColor.windowBackgroundColor
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.contentView = completionScrollView
        panel.isReleasedWhenClosed = false

        completionPanel = panel
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
                self?.hideCompletions()
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

    // MARK: - Autocomplete Logic

    private func updateCompletions(for text: String) {
        guard !text.isEmpty else {
            hideCompletions()
            return
        }

        let expanded = (text as NSString).expandingTildeInPath
        let parentDir: String
        let prefix: String

        if text.hasSuffix("/") {
            parentDir = expanded
            prefix = ""
        } else {
            parentDir = (expanded as NSString).deletingLastPathComponent
            prefix = (expanded as NSString).lastPathComponent
        }

        guard !parentDir.isEmpty else {
            hideCompletions()
            return
        }

        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: parentDir, isDirectory: &isDir), isDir.boolValue else {
            hideCompletions()
            return
        }

        guard let entries = try? fm.contentsOfDirectory(atPath: parentDir) else {
            hideCompletions()
            return
        }

        let homeDir = NSHomeDirectory()
        let usesTilde = text.hasPrefix("~")

        let matches: [String] = entries.compactMap { entry in
            guard !entry.hasPrefix(".") else { return nil }
            var entryIsDir: ObjCBool = false
            let fullPath = (parentDir as NSString).appendingPathComponent(entry)
            fm.fileExists(atPath: fullPath, isDirectory: &entryIsDir)
            guard entryIsDir.boolValue else { return nil }
            guard prefix.isEmpty || entry.lowercased().hasPrefix(prefix.lowercased()) else { return nil }
            if usesTilde && fullPath.hasPrefix(homeDir) {
                return "~" + String(fullPath.dropFirst(homeDir.count))
            }
            return fullPath
        }.sorted()

        completions = matches

        if completions.isEmpty {
            hideCompletions()
            return
        }

        completionTable.reloadData()
        completionTable.deselectAll(nil)
        showCompletionPanel()
    }

    private func showCompletionPanel() {
        guard let panel = completionPanel, let window = self.window else { return }

        let fieldFrameInWindow = pathField.convert(pathField.bounds, to: nil)
        let fieldFrameOnScreen = window.convertToScreen(fieldFrameInWindow)

        let panelWidth = fieldFrameOnScreen.width
        let rowHeight: CGFloat = 22
        let maxRows: CGFloat = 8
        let visibleRows = min(CGFloat(completions.count), maxRows)
        let panelHeight = visibleRows * rowHeight + 4

        let panelFrame = NSRect(
            x: fieldFrameOnScreen.minX,
            y: fieldFrameOnScreen.minY - panelHeight - 2,
            width: panelWidth,
            height: panelHeight
        )

        if panel.isVisible {
            panel.setFrame(panelFrame, display: true)
        } else {
            panel.setFrame(panelFrame, display: false)
            window.addChildWindow(panel, ordered: .above)
            panel.orderFront(nil)
        }
    }

    private func hideCompletions() {
        guard let panel = completionPanel, panel.isVisible else { return }
        panel.parent?.removeChildWindow(panel)
        panel.orderOut(nil)
    }

    private func adjustCompletionSelection(by delta: Int) {
        guard completionPanel?.isVisible == true, !completions.isEmpty else { return }
        let current = completionTable.selectedRow
        let next: Int
        if current == -1 {
            next = delta > 0 ? 0 : completions.count - 1
        } else {
            next = max(0, min(completions.count - 1, current + delta))
        }
        completionTable.selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)
        completionTable.scrollRowToVisible(next)
    }

    @discardableResult
    private func applySelectedCompletion() -> Bool {
        guard completionPanel?.isVisible == true else { return false }
        let row = completionTable.selectedRow
        guard row >= 0, row < completions.count else { return false }
        let selected = completions[row]
        let withSlash = selected.hasSuffix("/") ? selected : selected + "/"
        pathField.stringValue = withSlash
        hideCompletions()
        updateStartButton()
        updateCompletions(for: withSlash)
        return true
    }

    @objc private func completionClicked() {
        applySelectedCompletion()
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

// MARK: - NSTextFieldDelegate

extension MainWindowController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard (obj.object as? NSTextField) === pathField else { return }
        updateStartButton()
        updateCompletions(for: pathField.stringValue)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard control === pathField else { return false }
        switch commandSelector {
        case #selector(NSResponder.moveDown(_:)):
            adjustCompletionSelection(by: 1)
            return completionPanel?.isVisible == true
        case #selector(NSResponder.moveUp(_:)):
            adjustCompletionSelection(by: -1)
            return completionPanel?.isVisible == true
        case #selector(NSResponder.insertNewline(_:)):
            return applySelectedCompletion()
        case #selector(NSResponder.cancelOperation(_:)):
            if completionPanel?.isVisible == true {
                hideCompletions()
                return true
            }
            return false
        default:
            return false
        }
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard (obj.object as? NSTextField) === pathField else { return }
        // Delay to allow a click in the completion panel to register first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.hideCompletions()
        }
    }
}

// MARK: - NSTableViewDataSource & NSTableViewDelegate

extension MainWindowController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return completions.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let path = completions[row]
        let name = (path as NSString).lastPathComponent

        let cellView = NSTableCellView()
        cellView.toolTip = path

        let label = NSTextField(labelWithString: name)
        label.font = NSFont.systemFont(ofSize: 13)
        label.lineBreakMode = .byTruncatingMiddle
        label.translatesAutoresizingMaskIntoConstraints = false
        cellView.addSubview(label)
        cellView.textField = label

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -6),
            label.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
        ])

        return cellView
    }
}
