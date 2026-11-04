//
//  AppShortcuts.swift
//  Notes
//
//  Siri and Shortcuts actions. They also appear in Spotlight and can be set to Back Tap.
//

import AppIntents
import SwiftData

/// Saves a note without opening the app ("Add to CloudNote").
struct AddNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Note"
    static let description = IntentDescription("Saves a new note in CloudNote AI.")

    @Parameter(title: "Text", inputOptions: String.IntentInputOptions(multiline: true))
    var text: String

    static var parameterSummary: some ParameterSummary {
        Summary("Add note \(\.$text)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .result(dialog: "There was nothing to save.")
        }
        let (title, body) = NoteText.split(trimmed)
        let context = AppDatabase.container.mainContext
        context.insert(NotesItem(title: title, desc: body, isPinned: false))
        try context.save()
        SharedStore.reloadWidgets()
        return .result(dialog: "Saved “\(title)”.")
    }
}

/// Adds a task to the Todo list ("Add a task in CloudNote").
struct AddTodoIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Task"
    static let description = IntentDescription("Adds a task to your CloudNote AI todo list.")

    @Parameter(title: "Task")
    var task: String

    static var parameterSummary: some ParameterSummary {
        Summary("Add task \(\.$task)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = task.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .result(dialog: "There was nothing to add.")
        }
        let context = AppDatabase.container.mainContext
        context.insert(TodoItem(title: String(trimmed.prefix(200)), isCompleted: false))
        try context.save()
        SharedStore.reloadWidgets()
        return .result(dialog: "Added “\(trimmed)” to your tasks.")
    }
}

struct CloudNoteShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddNoteIntent(),
            phrases: [
                "Add to \(.applicationName)",
                "Add a note in \(.applicationName)",
                "Save a note in \(.applicationName)"
            ],
            shortTitle: "Add Note",
            systemImageName: "square.and.pencil"
        )
        AppShortcut(
            intent: AddTodoIntent(),
            phrases: [
                "Add a task in \(.applicationName)",
                "Add a todo in \(.applicationName)"
            ],
            shortTitle: "Add Task",
            systemImageName: "checklist"
        )
        AppShortcut(
            intent: NewNoteIntent(),
            phrases: [
                "New note in \(.applicationName)",
                "Open a new note in \(.applicationName)"
            ],
            shortTitle: "New Note",
            systemImageName: "plus.square"
        )
    }
}
