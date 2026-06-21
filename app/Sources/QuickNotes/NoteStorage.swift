import Foundation
import Combine

class NoteStorage: ObservableObject {
    static let shared = NoteStorage()

    @Published var notes: [Note] = []

    private let notesDir: URL
    private let notesFile: URL
    private var fileMonitor: DispatchSourceFileSystemObject?
    private var saveDebouncer: AnyCancellable?
    private let saveSubject = PassthroughSubject<Void, Never>()

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        notesDir = home.appendingPathComponent(".quick-notes")
        notesFile = notesDir.appendingPathComponent("notes.json")
        ensureStorageExists()
        loadNotes()
        startFileMonitor()

        // Debounce saves: wait 0.5s after last edit before writing to disk
        saveDebouncer = saveSubject
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] in
                self?.saveToDisk()
            }
    }

    deinit {
        fileMonitor?.cancel()
        saveDebouncer?.cancel()
    }

    // MARK: - CRUD

    func createNote(title: String, content: String) {
        let now = Date().timeIntervalSince1970 * 1000
        let note = Note(
            id: UUID().uuidString.lowercased(),
            title: title,
            content: content,
            createdAt: now,
            updatedAt: now
        )
        notes.append(note)
        sortAndSave()
    }

    func updateNote(_ note: Note, title: String, content: String) {
        guard let index = notes.firstIndex(where: { $0.id == note.id }) else { return }
        notes[index].title = title
        notes[index].content = content
        notes[index].updatedAt = Date().timeIntervalSince1970 * 1000
        notes.sort { $0.updatedAt > $1.updatedAt }
        saveSubject.send() // debounced save
    }

    func deleteNote(_ note: Note) {
        notes.removeAll { $0.id == note.id }
        sortAndSave()
    }

    func deleteNote(id: String) {
        notes.removeAll { $0.id == id }
        sortAndSave()
    }

    /// Force immediate save (used before app termination)
    func flush() {
        saveToDisk()
    }

    // MARK: - Persistence

    private func ensureStorageExists() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: notesDir.path) {
            try? fm.createDirectory(at: notesDir, withIntermediateDirectories: true)
        }
        if !fm.fileExists(atPath: notesFile.path) {
            try? "[]".write(to: notesFile, atomically: true, encoding: .utf8)
        }
    }

    func loadNotes() {
        guard let data = try? Data(contentsOf: notesFile),
              let decoded = try? JSONDecoder().decode([Note].self, from: data) else {
            notes = []
            return
        }
        notes = decoded.sorted { $0.updatedAt > $1.updatedAt }
    }

    private func sortAndSave() {
        notes.sort { $0.updatedAt > $1.updatedAt }
        saveToDisk() // immediate save for create/delete
    }

    private func saveToDisk() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        guard let data = try? encoder.encode(notes) else { return }
        try? data.write(to: notesFile, options: .atomic)
    }

    // MARK: - File Monitoring (detect changes from Raycast extension)

    private func startFileMonitor() {
        let fd = open(notesFile.path, O_EVTONLY)
        guard fd >= 0 else { return }

        fileMonitor = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename],
            queue: .main
        )

        fileMonitor?.setEventHandler { [weak self] in
            self?.loadNotes()
        }

        fileMonitor?.setCancelHandler {
            close(fd)
        }

        fileMonitor?.resume()
    }
}
