//
//  TodoScreen.swift
//  Notes
//
//  Created by Muhammad Khubaib Imtiaz on 20/10/2024.
//  Rewritten with enhanced features and design.
//

import SwiftUI
import SwiftData

struct TodoScreen: View {

    @Environment(\.modelContext) private var context
    @EnvironmentObject var appManager: AppManager
    @Environment(\.colorScheme) private var colorScheme

    // Fetch all tasks
    @Query private var allTodos: [TodoItem]

    // UI State
    @State private var searchText: String = ""
    @State private var filter: Filter = .all
    @State private var sort: Sort = .dueDate
    @State private var isPresentingEditor: Bool = false
    @State private var editingItem: TodoItem?
    @State private var quickAddTitle: String = ""

    // Bulk selection
    @State private var selection: Set<String> = []
    @State private var editMode: EditMode = .inactive

    var body: some View {
        NavigationStack {
            contentList
            // Quick add sits at the bottom, within thumb reach (like Reminders).
            .safeAreaInset(edge: .bottom) {
                if editMode == .active {
                    // Bulk actions get their own bar while selecting; the tab bar is hidden.
                    BulkActionBar(
                        selectedCount: selection.count,
                        allSelected: !visibleIDs.isEmpty && selection == visibleIDs,
                        onSelectAll: {
                            selection = selection == visibleIDs ? [] : visibleIDs
                        },
                        onComplete: { bulkToggleComplete(true) },
                        onUncomplete: { bulkToggleComplete(false) },
                        onDelete: bulkDelete
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                } else {
                    QuickAddBar(title: $quickAddTitle, onAdd: addQuickTask)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
            }
            .toolbar(editMode == .active ? .hidden : .visible, for: .tabBar)
            .animation(.snappy, value: editMode)
            .navigationTitle("Todo")
            .navigationSubtitle(subtitle)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker(selection: $filter) {
                            Label("All Tasks", systemImage: "tray").tag(Filter.all)
                            Label("Active", systemImage: "circle").tag(Filter.active)
                            Label("Completed", systemImage: "checkmark.circle").tag(Filter.completed)
                        } label: {
                            Text("Show")
                        }
                        .pickerStyle(.inline)
                        Picker("Sort", selection: $sort) {
                            Label("Title A–Z", systemImage: "textformat").tag(Sort.titleAsc)
                            Label("Title Z–A", systemImage: "textformat.size.smaller").tag(Sort.titleDesc)
                            Label("Status", systemImage: "checkmark.circle").tag(Sort.status)
                            Label("Due Date", systemImage: "calendar").tag(Sort.dueDate)
                            Label("Priority", systemImage: "flag").tag(Sort.priority)
                        }
                        .pickerStyle(.inline)
                        Divider()
                        Button(role: .destructive, action: clearCompleted) {
                            Label("Clear Completed", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: filter == .all
                              ? "line.3.horizontal.decrease.circle"
                              : "line.3.horizontal.decrease.circle.fill")
                    }
                    .accessibilityLabel("View options")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if !filteredSortedTodos.isEmpty {
                        EditButton()
                    }
                    Button {
                        editingItem = nil
                        isPresentingEditor = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .imageScale(.large)
                    }
                    .accessibilityLabel("New Task")
                }
            }
            .environment(\.editMode, $editMode)
            .onChange(of: editMode) { _, newValue in
                if newValue == .inactive {
                    selection.removeAll()
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
            .onChange(of: appManager.pendingRoute, initial: true) { _, route in
                // A reminder was tapped: open that task.
                if case .todo(let id) = route {
                    appManager.pendingRoute = nil
                    if let item = allTodos.first(where: { $0.id == id }) {
                        edit(item)
                    }
                }
            }
            .sheet(isPresented: $isPresentingEditor, onDismiss: {
                editingItem = nil
            }) {
                TaskEditorSheet(
                    draft: TodoDraft(editingItem),
                    isNew: editingItem == nil,
                    onCancel: {
                        isPresentingEditor = false
                    },
                    onSave: { draft in
                        save(draft)
                        isPresentingEditor = false
                    }
                )
                .id(editingItem?.id ?? "new") // Refresh the sheet for the selected todo
            }
        }
    }

    // MARK: - Derived Data

    private var filteredSortedTodos: [TodoItem] {
        var items = allTodos.filter { !$0.isDeleted }

        // Filter by search
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            items = items.filter {
                $0.title.localizedCaseInsensitiveContains(query) ||
                $0.notes.localizedCaseInsensitiveContains(query)
            }
        }

        // Filter by status
        switch filter {
        case .all:
            break
        case .active:
            items = items.filter { !$0.isCompleted }
        case .completed:
            items = items.filter { $0.isCompleted }
        }

        let byTitle: (TodoItem, TodoItem) -> Bool = {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }

        // Sort
        switch sort {
        case .titleAsc:
            items.sort(by: byTitle)
        case .titleDesc:
            items.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending }
        case .status:
            // Incomplete first, then title
            items.sort {
                $0.isCompleted == $1.isCompleted ? byTitle($0, $1) : (!$0.isCompleted && $1.isCompleted)
            }
        case .dueDate:
            // Soonest first; tasks without a due date go last
            items.sort {
                switch ($0.dueDate, $1.dueDate) {
                case let (a?, b?): a == b ? byTitle($0, $1) : a < b
                case (.some, nil): true
                case (nil, .some): false
                case (nil, nil): byTitle($0, $1)
                }
            }
        case .priority:
            items.sort {
                $0.priorityRaw == $1.priorityRaw ? byTitle($0, $1) : $0.priorityRaw > $1.priorityRaw
            }
        }

        return items
    }

    // MARK: - Views

    /// IDs of the tasks currently shown, for "Select All".
    private var visibleIDs: Set<String> {
        Set(filteredSortedTodos.map(\.id))
    }
    
    private var subtitle: String {
        let todos = allTodos.filter { !$0.isDeleted }
        let open = todos.filter { !$0.isCompleted }.count
        let overdue = todos.filter(\.isOverdue).count
        var text = open == 1 ? String(localized: "1 open task") : String(localized: "\(open) open tasks")
        if overdue > 0 { text += String(localized: " · \(overdue) overdue") }
        return text
    }
    
    private var emptyTitle: String {
        if allTodos.isEmpty { return String(localized: "No Tasks Yet") }
        if !searchText.isEmpty { return String(localized: "No Matching Tasks") }
        return filter == .completed ? String(localized: "Nothing Completed Yet") : String(localized: "All Done!")
    }
    
    private var emptyMessage: String {
        if allTodos.isEmpty { return String(localized: "Type a task below and press return to add it.") }
        if !searchText.isEmpty { return String(localized: "Try a different search.") }
        return filter == .completed ? String(localized: "Tasks you tick off show up here.") : String(localized: "You've finished every task.")
    }
    
    /// A group of tasks in the list, such as "Today" or "Overdue".
    private struct TaskGroup: Identifiable {
        let id: String
        let title: String
        var isOverdue = false
        var items: [TodoItem]
    }
    
    /// Tasks grouped by when they're due; completed ones go last.
    private var sections: [TaskGroup] {
        let calendar = Calendar.current
        let now = Date()
        var overdue: [TodoItem] = [], today: [TodoItem] = [], tomorrow: [TodoItem] = []
        var upcoming: [TodoItem] = [], noDate: [TodoItem] = [], done: [TodoItem] = []
        for item in filteredSortedTodos {
            if item.isCompleted {
                done.append(item)
            } else if let due = item.dueDate {
                if due < now && !calendar.isDateInToday(due) { overdue.append(item) }
                else if calendar.isDateInToday(due) { today.append(item) }
                else if calendar.isDateInTomorrow(due) { tomorrow.append(item) }
                else { upcoming.append(item) }
            } else {
                noDate.append(item)
            }
        }
        return [
            TaskGroup(id: "overdue", title: String(localized: "Overdue"), isOverdue: true, items: overdue),
            TaskGroup(id: "today", title: String(localized: "Today"), items: today),
            TaskGroup(id: "tomorrow", title: String(localized: "Tomorrow"), items: tomorrow),
            TaskGroup(id: "upcoming", title: String(localized: "Upcoming"), items: upcoming),
            TaskGroup(id: "nodate", title: String(localized: "No Due Date"), items: noDate),
            TaskGroup(id: "done", title: String(localized: "Completed"), items: done),
        ].filter { !$0.items.isEmpty }
    }
    
    private var contentList: some View {
        Group {
            if filteredSortedTodos.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: allTodos.isEmpty ? "checklist" : "checkmark.circle")
                        .font(.system(size: 52, weight: .light))
                        .foregroundStyle(.secondary)
                    Text(emptyTitle)
                        .font(.title3.bold())
                    Text(emptyMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List(selection: $selection) {
                    ForEach(sections) { group in
                    Section {
                    ForEach(group.items) { item in
                        TodoRow(
                            item: item,
                            onToggle: { toggleComplete(item) },
                            onEdit: { edit(item) }
                        )
                        .tag(item.id) // for multi-select
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                delete([item])
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                toggleComplete(item)
                            } label: {
                                if item.isCompleted {
                                    Label("Uncomplete", systemImage: "xmark.circle")
                                } else {
                                    Label("Complete", systemImage: "checkmark.circle.fill")
                                }
                            }
                            .tint(item.isCompleted ? .orange : .green)
                        }
                        .contextMenu {
                            Button {
                                edit(item)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button {
                                toggleComplete(item)
                            } label: {
                                if item.isCompleted {
                                    Label("Mark as Active", systemImage: "xmark.circle")
                                } else {
                                    Label("Mark as Completed", systemImage: "checkmark.circle")
                                }
                            }
                            Divider()
                            Button(role: .destructive) {
                                delete([item])
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    } header: {
                        HStack(spacing: 6) {
                            Text(group.title)
                            Text("\(group.items.count)")
                                .foregroundStyle(.tertiary)
                        }
                        .foregroundStyle(group.isOverdue ? Color.red : Color.secondary)
                    }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    // MARK: - Actions

    private func edit(_ item: TodoItem) {
        editingItem = item
        isPresentingEditor = true
    }

    private func save(_ draft: TodoDraft) {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        let item: TodoItem
        if let editingItem {
            item = editingItem
        } else {
            item = TodoItem(title: title, isCompleted: false)
            context.insert(item)
        }
        item.title = title
        item.notes = draft.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        item.priority = draft.priority
        item.dueDate = draft.hasDueDate ? draft.dueDate : nil
        item.hasReminder = draft.hasDueDate && draft.hasReminder
        try? context.save()
        ReminderScheduler.schedule(item)
        Haptics.success()
    }

    private func toggleComplete(_ item: TodoItem) {
        item.isCompleted.toggle()
        Haptics.tap()
        try? context.save()
        // Cancels the reminder when completed, restores it when reopened.
        ReminderScheduler.schedule(item)
    }

    private func delete(_ items: [TodoItem]) {
        for item in items {
            ReminderScheduler.cancel(todoID: item.id)
            context.delete(item)
        }
        try? context.save()
    }

    private func addQuickTask() {
        let trimmed = quickAddTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let new = TodoItem(title: trimmed, isCompleted: false)
        context.insert(new)
        try? context.save()
        quickAddTitle = ""
    }

    private func clearCompleted() {
        delete(allTodos.filter { $0.isCompleted })
    }

    private func bulkToggleComplete(_ completed: Bool) {
        let toUpdate = allTodos.filter { selection.contains($0.id) }
        for item in toUpdate {
            item.isCompleted = completed
        }
        try? context.save()
        toUpdate.forEach { ReminderScheduler.schedule($0) }
        selection.removeAll()
        editMode = .inactive
    }

    private func bulkDelete() {
        delete(allTodos.filter { selection.contains($0.id) })
        selection.removeAll()
        editMode = .inactive
    }
}

// MARK: - Row

private struct TodoRow: View {
    let item: TodoItem
    var onToggle: () -> Void
    var onEdit: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isCompleted ? .green : .secondary)
                    .imageScale(.large)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if item.priority != .none {
                        Image(systemName: "flag.fill")
                            .foregroundStyle(item.priority.color)
                            .imageScale(.small)
                            .accessibilityLabel("\(item.priority.title) priority")
                    }
                    Text(item.title)
                        .strikethrough(item.isCompleted, pattern: .solid, color: .secondary)
                        .foregroundStyle(item.isCompleted ? .secondary : .primary)
                        .lineLimit(2)
                }

                if !item.notes.isEmpty {
                    Text(item.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let due = item.dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: item.hasReminder ? "bell.fill" : "calendar")
                        Text(dueText(due))
                    }
                    .font(.caption)
                    .foregroundStyle(item.isOverdue ? .red : .secondary)
                }
            }

            Spacer()

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .imageScale(.medium)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit")
        }
        .contentShape(Rectangle())
    }

    private func dueText(_ date: Date) -> String {
        let calendar = Calendar.current
        let time = date.formatted(date: .omitted, time: .shortened)
        if calendar.isDateInToday(date) { return String(localized: "Today, \(time)") }
        if calendar.isDateInTomorrow(date) { return String(localized: "Tomorrow, \(time)") }
        if calendar.isDateInYesterday(date) { return String(localized: "Yesterday, \(time)") }
        return date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }
}

// MARK: - Bulk Action Bar

/// Shown at the bottom while selecting tasks with Edit.
private struct BulkActionBar: View {
    let selectedCount: Int
    let allSelected: Bool
    var onSelectAll: () -> Void
    var onComplete: () -> Void
    var onUncomplete: () -> Void
    var onDelete: () -> Void
    
    var body: some View {
        let hasSelection = selectedCount > 0
        HStack(spacing: 4) {
            Button(allSelected ? "Deselect All" : "Select All", action: onSelectAll)
                .font(.subheadline.weight(.medium))
            Spacer()
            Text(hasSelection ? "\(selectedCount) selected" : "Select tasks")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: onComplete) {
                Image(systemName: "checkmark.circle")
            }
            .accessibilityLabel("Mark as Completed")
            .disabled(!hasSelection)
            Button(action: onUncomplete) {
                Image(systemName: "arrow.uturn.backward.circle")
            }
            .accessibilityLabel("Mark as Active")
            .disabled(!hasSelection)
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .accessibilityLabel("Delete selected")
            .tint(.red)
            .disabled(!hasSelection)
        }
        .font(.title3)
        .buttonStyle(.borderless)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08)))
    }
}

// MARK: - Quick Add Bar

private struct QuickAddBar: View {
    @Binding var title: String
    var onAdd: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
            TextField("New task", text: $title)
                .submitLabel(.done)
                .onSubmit(onAdd)
            if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button("Add", action: onAdd)
                    .fontWeight(.semibold)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08)))
    }
}

// MARK: - Task Editor Sheet

/// Editable copy of a todo, so Cancel leaves the saved task untouched.
private struct TodoDraft {
    var title = ""
    var notes = ""
    var priority: TodoPriority = .none
    var hasDueDate = false
    var dueDate: Date = .nextHour
    var hasReminder = false

    init(_ item: TodoItem?) {
        guard let item else { return }
        title = item.title
        notes = item.notes
        priority = item.priority
        if let due = item.dueDate {
            hasDueDate = true
            dueDate = due
            hasReminder = item.hasReminder
        }
    }
}

private struct TaskEditorSheet: View {
    @State private var draft: TodoDraft
    @State private var showNotificationsOffAlert = false
    let isNew: Bool
    var onCancel: () -> Void
    var onSave: (TodoDraft) -> Void

    init(draft: TodoDraft, isNew: Bool, onCancel: @escaping () -> Void, onSave: @escaping (TodoDraft) -> Void) {
        self._draft = State(initialValue: draft)
        self.isNew = isNew
        self.onCancel = onCancel
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("What do you need to do?", text: $draft.title)
                        .textInputAutocapitalization(.sentences)
                    TextField("Notes", text: $draft.notes, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section {
                    Picker(selection: $draft.priority) {
                        ForEach(TodoPriority.allCases) { priority in
                            Text(priority.title).tag(priority)
                        }
                    } label: {
                        Label("Priority", systemImage: "flag")
                    }
                }

                Section {
                    Toggle(isOn: $draft.hasDueDate.animation()) {
                        Label("Due Date", systemImage: "calendar")
                    }
                    if draft.hasDueDate {
                        DatePicker("Due", selection: $draft.dueDate)
                        Toggle(isOn: $draft.hasReminder) {
                            Label("Remind me", systemImage: "bell")
                        }
                    }
                } footer: {
                    if draft.hasDueDate && draft.hasReminder {
                        Text("You'll get a notification at the due time.")
                    }
                }
            }
            .navigationTitle(isNew ? "New Task" : "Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: draft.hasReminder) { _, isOn in
                guard isOn else { return }
                Task {
                    if !(await ReminderScheduler.ensurePermission()) {
                        draft.hasReminder = false
                        showNotificationsOffAlert = true
                    }
                }
            }
            .alert("Notifications Are Off", isPresented: $showNotificationsOffAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Allow notifications for this app in the Settings app to get reminders.")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                    }
                    .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    TodoScreen()
        .modelContainer(for: [TodoItem.self])
        .environmentObject(AppManager())
}
