import AppKit
import SwiftUI

/// Manages multiple independent floating note panels
class PanelManager: ObservableObject {
    static let shared = PanelManager()

    private var panels: [String: NotePanel] = [:]
    private let storage = NoteStorage.shared

    var hasVisiblePanels: Bool {
        panels.values.contains { $0.isVisible }
    }

    func createNewNote() {
        storage.createNote(title: "", content: "")
        if let note = storage.notes.first {
            openPanel(for: note, isNew: true)
        }
    }

    func restoreAll() {
        storage.loadNotes()
        for note in storage.notes {
            openPanel(for: note)
        }
    }

    func showAll() {
        for (_, panel) in panels {
            panel.makeKeyAndOrderFront(nil)
        }
        // Also open panels for notes that don't have one
        for note in storage.notes {
            if panels[note.id] == nil {
                openPanel(for: note)
            }
        }
    }

    func hideAll() {
        for (_, panel) in panels {
            panel.orderOut(nil)
        }
    }

    func saveAll() {
        for (id, panel) in panels {
            UserDefaults.standard.set(
                NSStringFromRect(panel.frame),
                forKey: "panel-frame-\(id)"
            )
        }
    }

    func closePanel(for noteId: String) {
        panels[noteId]?.close()
        panels.removeValue(forKey: noteId)
    }

    func hidePanel(for noteId: String) {
        if let panel = panels[noteId] {
            // Save position before hiding
            UserDefaults.standard.set(
                NSStringFromRect(panel.frame),
                forKey: "panel-frame-\(noteId)"
            )
            panel.orderOut(nil)
        }
    }

    func deleteNote(id: String) {
        let alert = NSAlert()
        alert.messageText = "Delete Note?"
        alert.informativeText = "This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.buttons.first?.hasDestructiveAction = true

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            closePanel(for: id)
            storage.deleteNote(id: id)
        }
    }

    private func openPanel(for note: Note, isNew: Bool = false) {
        guard panels[note.id] == nil else {
            panels[note.id]?.makeKeyAndOrderFront(nil)
            return
        }

        let panel = NotePanel(note: note, storage: storage, panelManager: self, focusTitle: isNew)

        // Restore saved position or find non-overlapping position
        if let frameStr = UserDefaults.standard.string(forKey: "panel-frame-\(note.id)") {
            let frame = NSRectFromString(frameStr)
            panel.setFrame(frame, display: true)
        } else {
            let newFrame = findNonOverlappingPosition(for: panel)
            panel.setFrame(newFrame, display: true)
        }

        panel.makeKeyAndOrderFront(nil)
        panels[note.id] = panel
    }

    /// Find a position that doesn't overlap with existing visible panels
    /// Order: start from top-right, then go downward
    private func findNonOverlappingPosition(for panel: NSPanel) -> NSRect {
        guard let screen = NSScreen.main else {
            panel.center()
            return panel.frame
        }

        let panelSize = panel.frame.size
        let screenFrame = screen.visibleFrame
        let gap: CGFloat = 20

        let startX = screenFrame.maxX - panelSize.width - 40
        let startY = screenFrame.maxY - panelSize.height - 40

        let existingFrames = panels.values
            .filter { $0.isVisible }
            .map { $0.frame }

        for col in 0..<10 {
            for row in 0..<20 {
                let x = startX - CGFloat(col) * (panelSize.width + gap)
                let y = startY - CGFloat(row) * (panelSize.height + gap)

                guard x >= screenFrame.minX,
                      y >= screenFrame.minY else { continue }

                let candidate = NSRect(x: x, y: y, width: panelSize.width, height: panelSize.height)

                let hasOverlap = existingFrames.contains { existing in
                    candidate.intersects(existing)
                }

                if !hasOverlap {
                    return candidate
                }
            }
        }

        panel.center()
        var frame = panel.frame
        frame.origin.x += CGFloat(panels.count) * gap
        return frame
    }
}

// MARK: - Single Note Panel

class NotePanel: NSPanel {
    let noteId: String
    private weak var panelManager: PanelManager?

    init(note: Note, storage: NoteStorage, panelManager: PanelManager, focusTitle: Bool = false) {
        self.noteId = note.id
        self.panelManager = panelManager

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 220),
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Float above other windows
        level = .floating
        isFloatingPanel = true

        // Appearance
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        isMovableByWindowBackground = true
        backgroundColor = NSColor.windowBackgroundColor
        isOpaque = false
        hasShadow = true

        // Allow key input
        becomesKeyOnlyIfNeeded = false

        // Min size
        minSize = NSSize(width: 200, height: 150)

        // Set content
        let view = NoteCardView(note: note, storage: storage, panelManager: panelManager, focusTitle: focusTitle)
        contentView = NSHostingView(rootView: view)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let config = ShortcutConfig.shared.shortcuts
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let key = event.charactersIgnoringModifiers

        // Block Escape from closing the panel
        if event.keyCode == 53 {
            return true
        }
        // ⌘F → find in note
        if flags == .command && key == "f" {
            activateFindBar()
            return true
        }
        // New note
        if config.newNote.matches(event: event) {
            panelManager?.createNewNote()
            return true
        }
        // Delete note
        if config.deleteNote.matches(event: event) {
            panelManager?.deleteNote(id: noteId)
            return true
        }
        // Hide note
        if config.hideNote.matches(event: event) {
            panelManager?.hidePanel(for: noteId)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    private func activateFindBar() {
        guard let contentView = self.contentView else { return }
        if let textView = findTextView(in: contentView) {
            textView.usesFindBar = true
            textView.isIncrementalSearchingEnabled = true
            textView.performFindPanelAction(NSTextFinder.Action.showFindInterface)
        }
    }

    private func findTextView(in view: NSView) -> NSTextView? {
        for subview in view.subviews {
            if let textView = subview as? NSTextView {
                return textView
            }
            if let found = findTextView(in: subview) {
                return found
            }
        }
        return nil
    }

    override func cancelOperation(_ sender: Any?) {
        // Do nothing — prevent Escape from closing
    }

    // Red X button → hide instead of close (notes are persistent)
    override func close() {
        UserDefaults.standard.set(
            NSStringFromRect(frame),
            forKey: "panel-frame-\(noteId)"
        )
        panelManager?.hidePanel(for: noteId)
    }
}

// MARK: - Note Card View (content of each floating panel)

struct NoteCardView: View {
    let note: Note
    @ObservedObject var storage: NoteStorage
    weak var panelManager: PanelManager?
    @State private var title: String
    @State private var content: String
    @FocusState private var isTitleFocused: Bool
    @State private var lastSavedTime: Double
    private let shouldFocusTitle: Bool

    init(note: Note, storage: NoteStorage, panelManager: PanelManager?, focusTitle: Bool = false) {
        self.note = note
        self.storage = storage
        self.panelManager = panelManager
        self.shouldFocusTitle = focusTitle
        _title = State(initialValue: note.title)
        _content = State(initialValue: note.content)
        _lastSavedTime = State(initialValue: note.updatedAt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title
            PlainTextField(text: $title, placeholder: "Title", font: .boldSystemFont(ofSize: 14), onTab: {
                // Focus content editor on Tab
                DispatchQueue.main.async {
                    if let window = NSApp.keyWindow,
                       let contentView = window.contentView {
                        findAndFocusTextView(in: contentView)
                    }
                }
            })
            .frame(height: 22)
            .padding(.horizontal, 14)
            .padding(.top, 32)
            .padding(.bottom, 6)
            .onChange(of: title) { _, newValue in
                storage.updateNote(note, title: newValue, content: content)
                lastSavedTime = Date().timeIntervalSince1970 * 1000
            }

            Divider()
                .padding(.horizontal, 14)

            // Content
            PlainTextEditor(text: $content, placeholder: "Write something...")
                .padding(.horizontal, 10)
                .padding(.top, 6)
                .onChange(of: content) { _, newValue in
                    storage.updateNote(note, title: title, content: newValue)
                    lastSavedTime = Date().timeIntervalSince1970 * 1000
                }

            // Bottom bar
            HStack {
                Text(formatDate(lastSavedTime))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button(action: {
                    panelManager?.deleteNote(id: note.id)
                }) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Delete Note")
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if shouldFocusTitle {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isTitleFocused = true
                }
            }
        }
    }

    private func formatDate(_ timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp / 1000)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func findAndFocusTextView(in view: NSView) {
        for subview in view.subviews {
            if let textView = subview as? NSTextView {
                textView.window?.makeFirstResponder(textView)
                return
            }
            findAndFocusTextView(in: subview)
        }
    }
}

// MARK: - Plain TextField (no smart quotes)

struct PlainTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var font: NSFont
    var onTab: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.isEditable = true
        field.isBordered = false
        field.backgroundColor = .clear
        field.font = font
        field.placeholderString = placeholder
        field.focusRingType = .none
        field.lineBreakMode = .byTruncatingTail
        field.delegate = context.coordinator

        // Disable smart quotes on the field editor
        field.cell?.allowsEditingTextAttributes = false

        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: PlainTextField

        init(_ parent: PlainTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            // Handle Tab → jump to content
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                parent.onTab?()
                return true
            }
            // Handle Enter → jump to content
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onTab?()
                return true
            }
            return false
        }

        // Disable smart quotes in field editor
        func control(_ control: NSControl, textShouldBeginEditing fieldEditor: NSText) -> Bool {
            if let textView = fieldEditor as? NSTextView {
                textView.isAutomaticQuoteSubstitutionEnabled = false
                textView.isAutomaticDashSubstitutionEnabled = false
                textView.isAutomaticTextReplacementEnabled = false
            }
            return true
        }
    }
}

// MARK: - Plain Text Editor (no smart quotes/dashes, with placeholder)

struct PlainTextEditor: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        // Disable all smart substitutions
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false

        // Appearance
        textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        textView.textColor = NSColor.labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isRichText = false
        textView.allowsUndo = true

        // Remove border
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false

        // Text container
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true

        textView.delegate = context.coordinator
        textView.string = text

        // Set placeholder
        context.coordinator.placeholder = placeholder
        context.coordinator.updatePlaceholder(textView)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! NSTextView
        if textView.string != text {
            textView.string = text
            context.coordinator.updatePlaceholder(textView)
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: PlainTextEditor
        var placeholder: String = ""
        private var placeholderLabel: NSTextField?

        init(_ parent: PlainTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            updatePlaceholder(textView)
        }

        func textDidBeginEditing(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            updatePlaceholder(textView)
        }

        func updatePlaceholder(_ textView: NSTextView) {
            if placeholderLabel == nil && !placeholder.isEmpty {
                let label = NSTextField(labelWithString: placeholder)
                label.textColor = NSColor.placeholderTextColor
                label.font = textView.font
                label.isEditable = false
                label.isBordered = false
                label.backgroundColor = .clear
                label.translatesAutoresizingMaskIntoConstraints = false
                textView.addSubview(label)
                NSLayoutConstraint.activate([
                    label.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 5),
                    label.topAnchor.constraint(equalTo: textView.topAnchor, constant: 0),
                ])
                placeholderLabel = label
            }
            placeholderLabel?.isHidden = !textView.string.isEmpty
        }
    }
}
