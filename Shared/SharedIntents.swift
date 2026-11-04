//
//  SharedIntents.swift
//  Shared by the app and the widgets.
//

import AppIntents
import SwiftData
import UserNotifications

/// Opens the app on a blank new note. Used by the Control Center / Lock Screen control.
struct NewNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "New Note"
    static let description = IntentDescription("Opens CloudNote AI on a new note.")

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(AppRoute.newNote.url))
    }
}

/// Ticks a todo on or off from the Tasks widget, without opening the app.
struct ToggleTodoIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Task"
    static let isDiscoverable = false

    @Parameter(title: "Task ID")
    var todoID: String

    init() {}

    init(todoID: String) {
        self.todoID = todoID
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let container = try SharedStore.makeContainer(syncWithICloud: false)
        let context = container.mainContext
        let id = todoID
        var descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        if let todo = try context.fetch(descriptor).first {
            todo.isCompleted.toggle()
            try context.save()
            if todo.isCompleted {
                // Same identifier the app's ReminderScheduler uses. The app reschedules
                // reminders for reopened tasks the next time it becomes active.
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["todo.\(id)"])
            }
        }
        return .result()
    }
}
