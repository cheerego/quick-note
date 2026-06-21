import SwiftUI
import Carbon

struct PreferencesView: View {
    @ObservedObject var config = ShortcutConfig.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Keyboard Shortcuts")
                .font(.title2.bold())

            VStack(spacing: 12) {
                ShortcutRow(
                    label: "Toggle Notes",
                    description: "Show/hide all notes (global)",
                    shortcut: config.shortcuts.toggleNotes
                ) { newItem in
                    config.update(\.toggleNotes, with: newItem)
                }

                Divider()

                ShortcutRow(
                    label: "New Note",
                    description: "Create a new note",
                    shortcut: config.shortcuts.newNote
                ) { newItem in
                    config.update(\.newNote, with: newItem)
                }

                Divider()

                ShortcutRow(
                    label: "Delete Note",
                    description: "Delete the focused note",
                    shortcut: config.shortcuts.deleteNote
                ) { newItem in
                    config.update(\.deleteNote, with: newItem)
                }

                Divider()

                ShortcutRow(
                    label: "Hide Note",
                    description: "Hide the focused note",
                    shortcut: config.shortcuts.hideNote
                ) { newItem in
                    config.update(\.hideNote, with: newItem)
                }
            }
            .padding()
            .background(Color.primary.opacity(0.04))
            .cornerRadius(10)

            Spacer()
        }
        .padding(24)
        .frame(width: 420, height: 340)
    }
}

// MARK: - Shortcut Row

struct ShortcutRow: View {
    let label: String
    let description: String
    let shortcut: ShortcutItem
    let onChange: (ShortcutItem) -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.body.bold())
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            KeyRecorderButton(shortcut: shortcut, onChange: onChange)
        }
    }
}

// MARK: - Key Recorder Button

struct KeyRecorderButton: View {
    let shortcut: ShortcutItem
    let onChange: (ShortcutItem) -> Void
    @State private var isRecording = false

    var body: some View {
        Button(action: { isRecording = true }) {
            Text(isRecording ? "Press keys..." : shortcut.displayString)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isRecording ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.08))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isRecording ? Color.accentColor : Color.clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .background(
            KeyRecorderView(isRecording: $isRecording, onChange: onChange)
                .frame(width: 0, height: 0)
        )
    }
}

// MARK: - Key Recorder (NSView-based event capture)

struct KeyRecorderView: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onChange: (ShortcutItem) -> Void

    func makeNSView(context: Context) -> KeyCaptureView {
        let view = KeyCaptureView()
        view.onKeyRecorded = { item in
            onChange(item)
            isRecording = false
        }
        view.onCancel = {
            isRecording = false
        }
        return view
    }

    func updateNSView(_ nsView: KeyCaptureView, context: Context) {
        if isRecording {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

class KeyCaptureView: NSView {
    var onKeyRecorded: ((ShortcutItem) -> Void)?
    var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        // Escape cancels recording
        if event.keyCode == 53 {
            onCancel?()
            return
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Require at least one modifier
        guard !flags.isEmpty else { return }

        guard let chars = event.charactersIgnoringModifiers?.lowercased(), !chars.isEmpty else { return }

        // Build modifier list
        var modifiers: [String] = []
        if flags.contains(.control) { modifiers.append("control") }
        if flags.contains(.option) { modifiers.append("option") }
        if flags.contains(.shift) { modifiers.append("shift") }
        if flags.contains(.command) { modifiers.append("command") }

        let key = chars.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return }

        let item = ShortcutItem(key: key, modifiers: modifiers)
        onKeyRecorded?(item)
    }
}
