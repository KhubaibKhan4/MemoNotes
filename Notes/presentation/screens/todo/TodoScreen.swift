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
    @State private var sort: Sort = .titleAsc
    @State private var isPresentingEditor: Bool = false
    @State private var editingItem: TodoItem?
    @State private var quickAddTitle: String = ""
    
    // Bulk selection
    @State private var selection: Set<String> = []
    @State private var editMode: EditMode = .inactive
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                QuickAddBar(title: $quickAddTitle, onAdd: addQuickTask)
                    .padding(.horizontal)
                    .padding(.top, 8)
                filterControl
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                contentList
            }
            .navigationTitle("Todo")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Sort", selection: $sort) {
                            Label("Title A–Z", systemImage: "textformat").tag(Sort.titleAsc)
                            Label("Title Z–A", systemImage: "textformat.size.smaller").tag(Sort.titleDesc)
                            Label("Status", systemImage: "checkmark.circle").tag(Sort.status)
                        }
                        Divider()
                        Button(role: .destructive, action: clearCompleted) {
                            Label("Clear Completed", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Options")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if !filteredSortedTodos.isEmpty {
                        EditButton()
                            .onChange(of: editMode) { _, _ in
                                if editMode == .inactive {
                                    selection.removeAll()
                                }
                            }
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
                ToolbarItemGroup(placement: .bottomBar) {
                    if editMode == .active && !selection.isEmpty {
                        Button {
                            bulkToggleComplete(true)
                        } label: {
                            Label("Complete", systemImage: "checkmark.circle.fill")
                        }
                        Button {
                            bulkToggleComplete(false)
                        } label: {
                            Label("Uncomplete", systemImage: "xmark.circle")
                        }
                        Spacer()
                        Button(role: .destructive, action: bulkDelete) {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .onChange(of: editMode) { _, newValue in
                if newValue == .inactive {
                    selection.removeAll()
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
            .preferredColorScheme(appManager.isDark ? .dark : .light)
            .sheet(isPresented: $isPresentingEditor, onDismiss: {
                editingItem = nil // Reset after dismiss
            }) {
                TaskEditorSheet(
                    title: editingItem?.title ?? "",
                    onCancel: {
                        isPresentingEditor = false
                        editingItem = nil // Reset on cancel
                    },
                    onSave: { title in
                        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else {
                            isPresentingEditor = false
                            editingItem = nil
                            return
                        }
                        if let item = editingItem {
                            item.title = trimmed
                        } else {
                            let new = TodoItem(title: trimmed, isCompleted: false)
                            context.insert(new)
                        }
                        try? context.save()
                        isPresentingEditor = false
                        editingItem = nil // Reset on save
                    }
                )
                .id(editingItem?.id ?? UUID().uuidString) // Always change id so sheet refreshes with correct todo
            }
        }
    }
    
    // MARK: - Derived Data
    
    private var filteredSortedTodos: [TodoItem] {
        var items = allTodos
        
        // Filter by search
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            items = items.filter { $0.title.localizedCaseInsensitiveContains(query) }
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
        
        // Sort
        switch sort {
        case .titleAsc:
            items.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .titleDesc:
            items.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending }
        case .status:
            // Incomplete first, then title
            items.sort {
                if $0.isCompleted == $1.isCompleted {
                    return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                } else {
                    return !$0.isCompleted && $1.isCompleted
                }
            }
        }
        
        return items
    }
    
    // MARK: - Views
    
    private var header: some View {
        let total = allTodos.count
        let completed = allTodos.filter { $0.isCompleted }.count
        let progress = total == 0 ? 0 : Double(completed) / Double(total)
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Tasks", systemImage: "checklist")
                    .font(.headline)
                Spacer()
                Text("\(completed)/\(total) done")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
            ProgressView(value: progress)
                .tint(.accentColor)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var filterControl: some View {
        Picker("Filter", selection: $filter) {
            Text("All").tag(Filter.all)
            Text("Active").tag(Filter.active)
            Text("Completed").tag(Filter.completed)
        }
        .pickerStyle(.segmented)
    }
    
    private var contentList: some View {
        Group {
            if filteredSortedTodos.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No tasks to show")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    if !searchText.isEmpty {
                        Text("Try changing your search or filters.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List(selection: $selection) {
                    ForEach(filteredSortedTodos) { item in
                        HStack(spacing: 12) {
                            Button {
                                item.isCompleted.toggle()
                                try? context.save()
                            } label: {
                                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(item.isCompleted ? .green : .secondary)
                                    .imageScale(.large)
                            }
                            .buttonStyle(.plain)
                            
                            Text(item.title)
                                .strikethrough(item.isCompleted, pattern: .solid, color: .secondary)
                                .foregroundStyle(item.isCompleted ? .secondary : .primary)
                                .lineLimit(2)
                            
                            Spacer()
                            
                            Button {
                                editingItem = item
                                isPresentingEditor = true
                            } label: {
                                Image(systemName: "pencil")
                                    .imageScale(.medium)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .contentShape(Rectangle())
                        .tag(item.id) // for multi-select
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                context.delete(item)
                                try? context.save()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                item.isCompleted.toggle()
                                try? context.save()
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
                                editingItem = item
                                isPresentingEditor = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button {
                                item.isCompleted.toggle()
                                try? context.save()
                            } label: {
                                if item.isCompleted {
                                    Label("Mark as Active", systemImage: "xmark.circle")
                                } else {
                                    Label("Mark as Completed", systemImage: "checkmark.circle")
                                }
                            }
                            Divider()
                            Button(role: .destructive) {
                                context.delete(item)
                                try? context.save()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
    
    // MARK: - Actions
    
    private func addQuickTask() {
        let trimmed = quickAddTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let new = TodoItem(title: trimmed, isCompleted: false)
        context.insert(new)
        try? context.save()
        quickAddTitle = ""
    }
    
    private func clearCompleted() {
        let completed = allTodos.filter { $0.isCompleted }
        for item in completed {
            context.delete(item)
        }
        try? context.save()
    }
    
    private func bulkToggleComplete(_ completed: Bool) {
        let toUpdate = allTodos.filter { selection.contains($0.id) }
        for item in toUpdate {
            item.isCompleted = completed
        }
        try? context.save()
        selection.removeAll()
        editMode = .inactive
    }
    
    private func bulkDelete() {
        let toDelete = allTodos.filter { selection.contains($0.id) }
        for item in toDelete {
            context.delete(item)
        }
        try? context.save()
        selection.removeAll()
        editMode = .inactive
    }
}

// MARK: - Quick Add Bar

private struct QuickAddBar: View {
    @Binding var title: String
    var onAdd: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            TextField("Quick add a task…", text: $title)
                .textFieldStyle(.roundedBorder)
                .onSubmit(onAdd)
            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .imageScale(.large)
            }
            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}

// MARK: - Task Editor Sheet

private struct TaskEditorSheet: View {
    @State private var internalTitle: String
    var onCancel: () -> Void
    var onSave: (String) -> Void
    
    init(title: String, onCancel: @escaping () -> Void, onSave: @escaping (String) -> Void) {
        self._internalTitle = State(initialValue: title)
        self.onCancel = onCancel
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Title")) {
                    TextField("What do you need to do?", text: $internalTitle)
                        .autocorrectionDisabled(false)
                        .textInputAutocapitalization(.sentences)
                }
            }
            .navigationTitle("Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(internalTitle)
                    }
                    .disabled(internalTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
