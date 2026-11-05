//
//  TodoItem.swift
//  Notes
//
//  Created by Muhammad Khubaib Imtiaz on 20/10/2024.
//
import SwiftUI
import SwiftData

@Model
class TodoItem: Identifiable {
    // Defaults are required for iCloud (CloudKit) sync; see NotesItem.swift.
    var id: String = UUID().uuidString
    var title: String = ""
    var isCompleted: Bool = false

    // Added for due dates and reminders. Default values let SwiftData
    // migrate existing stores automatically.
    var notes: String = ""
    var dueDate: Date? = nil
    /// When true, a notification fires at `dueDate`.
    var hasReminder: Bool = false
    var priorityRaw: Int = 0
    var createdAt: Date = Date()

    var priority: TodoPriority {
        get { TodoPriority(rawValue: priorityRaw) ?? .none }
        set { priorityRaw = newValue.rawValue }
    }

    var isOverdue: Bool {
        guard let dueDate, !isCompleted else { return false }
        return dueDate < Date()
    }

    init(
        title: String,
        isCompleted: Bool,
        notes: String = "",
        dueDate: Date? = nil,
        hasReminder: Bool = false,
        priority: TodoPriority = .none
    ) {
        self.id = UUID().uuidString
        self.title = title
        self.isCompleted = isCompleted
        self.notes = notes
        self.dueDate = dueDate
        self.hasReminder = hasReminder
        self.priorityRaw = priority.rawValue
        self.createdAt = Date()
    }
}

enum TodoPriority: Int, CaseIterable, Identifiable {
    case none = 0, low, medium, high

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .none: String(localized: "None")
        case .low: String(localized: "Low")
        case .medium: String(localized: "Medium")
        case .high: String(localized: "High")
        }
    }

    var color: Color {
        switch self {
        case .none: .secondary
        case .low: .blue
        case .medium: .orange
        case .high: .red
        }
    }
}
