//
//  NotesWidget.swift
//  NotesWidget
//
//  Home-screen and Lock Screen widgets, plus a "New Note" control for
//  Control Center and the Lock Screen.
//

import WidgetKit
import SwiftUI
import SwiftData
import AppIntents

@main
struct CloudNoteWidgets: WidgetBundle {
    var body: some Widget {
        NotesWidget()
        TasksWidget()
        NewNoteControl()
    }
}

// MARK: - Data

/// Plain copies of notes and todos, so widget views don't hold database objects.
struct NoteSnapshot: Identifiable {
    let id: String
    let title: String
    let preview: String
    let isPinned: Bool
}

struct TodoSnapshot: Identifiable {
    let id: String
    let title: String
    let isCompleted: Bool
    let dueDate: Date?
    let priority: TodoPriority
    let isOverdue: Bool
}

enum WidgetData {
    static func notes(limit: Int = 6) -> [NoteSnapshot] {
        guard let container = try? SharedStore.makeContainer(syncWithICloud: false) else { return [] }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<NotesItem>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        // Leave out notes in Recently Deleted.
        let all = ((try? context.fetch(descriptor)) ?? []).filter { $0.deletedAt == nil }
        // Pinned notes first, then the most recently edited.
        let ordered = all.filter(\.isPinned) + all.filter { !$0.isPinned }
        return ordered.prefix(limit).map {
            NoteSnapshot(
                id: $0.id,
                title: $0.title,
                preview: $0.desc.replacingOccurrences(of: "\n", with: " "),
                isPinned: $0.isPinned
            )
        }
    }

    static func openTodos(limit: Int = 8) -> (items: [TodoSnapshot], openCount: Int) {
        guard let container = try? SharedStore.makeContainer(syncWithICloud: false) else { return ([], 0) }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { !$0.isCompleted })
        let open = (try? context.fetch(descriptor)) ?? []
        // Soonest due first, then highest priority, then newest.
        let sorted = open.sorted { a, b in
            switch (a.dueDate, b.dueDate) {
            case let (x?, y?) where x != y: return x < y
            case (.some, nil): return true
            case (nil, .some): return false
            default:
                if a.priorityRaw != b.priorityRaw { return a.priorityRaw > b.priorityRaw }
                return a.createdAt > b.createdAt
            }
        }
        let items = sorted.prefix(limit).map {
            TodoSnapshot(
                id: $0.id,
                title: $0.title,
                isCompleted: $0.isCompleted,
                dueDate: $0.dueDate,
                priority: $0.priority,
                isOverdue: $0.isOverdue
            )
        }
        return (items, open.count)
    }
}

/// Shown instead of notes while App Lock is on.
struct LockedWidgetView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Notes Locked")
                .font(.headline)
            Text("Open CloudNote AI to view")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Notes widget

struct NotesEntry: TimelineEntry {
    let date: Date
    let notes: [NoteSnapshot]
    let isLocked: Bool
}

struct NotesProvider: TimelineProvider {
    func placeholder(in context: Context) -> NotesEntry {
        NotesEntry(date: .now, notes: [
            NoteSnapshot(id: "1", title: "Trip packing", preview: "Passport, charger, jacket", isPinned: true),
            NoteSnapshot(id: "2", title: "Meeting notes", preview: "Agenda and follow-ups", isPinned: false),
        ], isLocked: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (NotesEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NotesEntry>) -> Void) {
        // The app and Share Extension refresh widgets whenever notes change.
        completion(Timeline(entries: [entry()], policy: .after(.now.addingTimeInterval(3600))))
    }

    private func entry() -> NotesEntry {
        let locked = SharedStore.isAppLockEnabled
        return NotesEntry(date: .now, notes: locked ? [] : WidgetData.notes(), isLocked: locked)
    }
}

struct NotesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NotesWidget", provider: NotesProvider()) { entry in
            NotesWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Notes")
        .description("Your pinned and recent notes.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
    }
}

struct NotesWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NotesEntry

    var body: some View {
        if entry.isLocked {
            if family == .accessoryRectangular {
                Label("Notes Locked", systemImage: "lock.fill")
            } else {
                LockedWidgetView()
            }
        } else if entry.notes.isEmpty {
            emptyView
        } else {
            switch family {
            case .systemSmall:
                singleNote(entry.notes[0])
                    .widgetURL(AppRoute.note(id: entry.notes[0].id).url)
            case .accessoryRectangular:
                VStack(alignment: .leading) {
                    Text(entry.notes[0].title).font(.headline).lineLimit(1)
                    Text(entry.notes[0].preview).font(.caption).lineLimit(2)
                }
                .widgetURL(AppRoute.note(id: entry.notes[0].id).url)
            default:
                list(count: family == .systemLarge ? 6 : 3)
            }
        }
    }

    private var emptyView: some View {
        Link(destination: AppRoute.newNote.url) {
            VStack(spacing: 6) {
                Image(systemName: "square.and.pencil").font(.title2)
                Text("No notes yet").font(.headline)
                Text("Tap to write one").font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func singleNote(_ note: NoteSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                if note.isPinned {
                    Image(systemName: "pin.fill").foregroundStyle(.orange).font(.caption)
                }
                Text(note.title).font(.headline).lineLimit(2)
            }
            Text(note.preview)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(5)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func list(count: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Notes", systemImage: "note.text").font(.headline)
                Spacer()
                Link(destination: AppRoute.newNote.url) {
                    Image(systemName: "plus.circle.fill").font(.title3)
                }
            }
            ForEach(entry.notes.prefix(count)) { note in
                Link(destination: AppRoute.note(id: note.id).url) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            if note.isPinned {
                                Image(systemName: "pin.fill").foregroundStyle(.orange).font(.caption2)
                            }
                            Text(note.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                        }
                        if !note.preview.isEmpty {
                            Text(note.preview).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Tasks widget

struct TasksEntry: TimelineEntry {
    let date: Date
    let todos: [TodoSnapshot]
    let openCount: Int
    let isLocked: Bool
}

struct TasksProvider: TimelineProvider {
    func placeholder(in context: Context) -> TasksEntry {
        TasksEntry(date: .now, todos: [
            TodoSnapshot(id: "1", title: "Call dentist", isCompleted: false, dueDate: .now, priority: .high, isOverdue: false),
            TodoSnapshot(id: "2", title: "Buy groceries", isCompleted: false, dueDate: nil, priority: .none, isOverdue: false),
        ], openCount: 2, isLocked: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (TasksEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TasksEntry>) -> Void) {
        // Refresh every 15 minutes so "overdue" stays accurate.
        completion(Timeline(entries: [entry()], policy: .after(.now.addingTimeInterval(900))))
    }

    private func entry() -> TasksEntry {
        let locked = SharedStore.isAppLockEnabled
        let data: (items: [TodoSnapshot], openCount: Int) = locked ? ([], 0) : WidgetData.openTodos()
        return TasksEntry(date: .now, todos: data.items, openCount: data.openCount, isLocked: locked)
    }
}

struct TasksWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TasksWidget", provider: TasksProvider()) { entry in
            TasksWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(AppRoute.todos.url)
        }
        .configurationDisplayName("Tasks")
        .description("Your open tasks. Tap a circle to tick one off.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct TasksWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TasksEntry

    private var rows: Int {
        switch family {
        case .systemSmall: 3
        case .systemMedium: 3
        default: 8
        }
    }

    var body: some View {
        if entry.isLocked {
            LockedWidgetView()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Tasks", systemImage: "checklist").font(.headline)
                    Spacer()
                    Text("\(entry.openCount)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                if entry.todos.isEmpty {
                    Spacer()
                    Text("All done 🎉")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    ForEach(entry.todos.prefix(rows)) { todo in
                        row(todo)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func row(_ todo: TodoSnapshot) -> some View {
        HStack(alignment: .top, spacing: 8) {
            // Runs ToggleTodoIntent in the widget, without opening the app.
            Button(intent: ToggleTodoIntent(todoID: todo.id)) {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(todo.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 3) {
                    if todo.priority != .none {
                        Image(systemName: "flag.fill")
                            .font(.caption2)
                            .foregroundStyle(todo.priority.color)
                    }
                    Text(todo.title)
                        .font(.subheadline)
                        .lineLimit(1)
                }
                if let due = todo.dueDate, family != .systemSmall {
                    Text(due, format: .dateTime.month(.abbreviated).day().hour().minute())
                        .font(.caption2)
                        .foregroundStyle(todo.isOverdue ? .red : .secondary)
                }
            }
        }
    }
}

// MARK: - New Note control (Control Center / Lock Screen / Action button)

struct NewNoteControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.brikmas.aipowerednotes.sync.notes.NewNote") {
            ControlWidgetButton(action: NewNoteIntent()) {
                Label("New Note", systemImage: "square.and.pencil")
            }
        }
        .displayName("New Note")
        .description("Opens CloudNote AI on a new note.")
    }
}
