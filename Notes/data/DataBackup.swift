//
//  DataBackup.swift
//  Notes
//

import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// JSON backup of all notes and todos. Photos are included; videos are not,
/// because they can be hundreds of megabytes.
struct NotesBackup: Codable {
    var version: Int = 1
    var exportedAt: Date = Date()
    var notes: [Note]
    var todos: [Todo]

    struct Note: Codable {
        var id: String
        var title: String
        var desc: String
        var isPinned: Bool
        var latitude: Double?
        var longitude: Double?
        var images: [Data]?
        var tags: [String]
        var checklist: [ChecklistEntry]
        var createdAt: Date
        var updatedAt: Date
        // Optional so backups from older versions still import.
        var reminderDate: Date?
        var richText: Data?
        /// Folder name; folders are matched or created by name on import.
        var folder: String?
        var color: String?
    }

    struct ChecklistEntry: Codable {
        var id: String
        var title: String
        var isDone: Bool
    }

    struct Todo: Codable {
        var id: String
        var title: String
        var isCompleted: Bool
        // Optional so backups from older versions still import.
        var notes: String?
        var dueDate: Date?
        var hasReminder: Bool?
        var priority: Int?
        var createdAt: Date?
    }
}

/// Wraps backup JSON so it can be used with `fileExporter`.
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

@MainActor
enum DataManager {

    static func exportBackup(context: ModelContext) throws -> Data {
        // Notes in Recently Deleted aren't backed up.
        let notes = try context.fetch(FetchDescriptor<NotesItem>()).filter { !$0.isInTrash }
        let todos = try context.fetch(FetchDescriptor<TodoItem>())

        let backup = NotesBackup(
            notes: notes.map { note in
                NotesBackup.Note(
                    id: note.id,
                    title: note.title,
                    desc: note.desc,
                    isPinned: note.isPinned,
                    latitude: note.latitude,
                    longitude: note.longitude,
                    images: note.images,
                    tags: note.tags,
                    checklist: note.checklist.map {
                        NotesBackup.ChecklistEntry(id: $0.id, title: $0.title, isDone: $0.isDone)
                    },
                    createdAt: note.createdAt,
                    updatedAt: note.updatedAt,
                    reminderDate: note.reminderDate,
                    richText: note.richText,
                    folder: note.folder?.name,
                    color: note.colorName
                )
            },
            todos: todos.map {
                NotesBackup.Todo(
                    id: $0.id,
                    title: $0.title,
                    isCompleted: $0.isCompleted,
                    notes: $0.notes,
                    dueDate: $0.dueDate,
                    hasReminder: $0.hasReminder,
                    priority: $0.priorityRaw,
                    createdAt: $0.createdAt
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    /// Adds the backup's notes and todos. Items that already exist (same id) are skipped,
    /// so importing the same file twice doesn't create duplicates.
    static func importBackup(_ data: Data, context: ModelContext) throws -> (notes: Int, todos: Int) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(NotesBackup.self, from: data)

        let existingNoteIDs = Set(try context.fetch(FetchDescriptor<NotesItem>()).map(\.id))
        let existingTodoIDs = Set(try context.fetch(FetchDescriptor<TodoItem>()).map(\.id))

        var folders = Dictionary(
            (try context.fetch(FetchDescriptor<NoteFolder>())).map { ($0.name.lowercased(), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        func folder(named name: String?) -> NoteFolder? {
            guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return nil }
            if let existing = folders[name.lowercased()] { return existing }
            let created = NoteFolder(name: name)
            context.insert(created)
            folders[name.lowercased()] = created
            return created
        }

        var addedNotes = 0
        for entry in backup.notes where !existingNoteIDs.contains(entry.id) {
            let note = NotesItem(
                title: entry.title,
                desc: entry.desc,
                isPinned: entry.isPinned,
                images: entry.images,
                tags: entry.tags,
                checklist: entry.checklist.map { ChecklistItem(id: $0.id, title: $0.title, isDone: $0.isDone) },
                createdAt: entry.createdAt,
                updatedAt: entry.updatedAt
            )
            note.id = entry.id
            note.latitude = entry.latitude
            note.longitude = entry.longitude
            note.reminderDate = entry.reminderDate
            note.richText = entry.richText
            note.folder = folder(named: entry.folder)
            note.colorName = entry.color
            context.insert(note)
            addedNotes += 1
        }

        var addedTodos = 0
        for entry in backup.todos where !existingTodoIDs.contains(entry.id) {
            let todo = TodoItem(
                title: entry.title,
                isCompleted: entry.isCompleted,
                notes: entry.notes ?? "",
                dueDate: entry.dueDate,
                hasReminder: entry.hasReminder ?? false,
                priority: TodoPriority(rawValue: entry.priority ?? 0) ?? .none
            )
            todo.id = entry.id
            if let createdAt = entry.createdAt { todo.createdAt = createdAt }
            context.insert(todo)
            addedTodos += 1
        }

        try context.save()
        return (addedNotes, addedTodos)
    }

    /// Deletes every note, checklist item, todo and saved video.
    static func deleteAllData(context: ModelContext) throws {
        // Deleting notes cascades to their checklist items; the second pass catches orphans.
        try context.fetch(FetchDescriptor<NotesItem>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<ChecklistItem>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<TodoItem>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<NoteFolder>()).forEach { context.delete($0) }
        try context.save()
        MediaStore.deleteAllVideos()
        MediaStore.deleteAllAudio()
        SpotlightIndex.deleteEverything()
    }

    static func backupFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "MemoNotes-Backup-\(formatter.string(from: Date()))"
    }
}
