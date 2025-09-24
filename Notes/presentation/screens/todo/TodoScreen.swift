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
    
    // Fetch all tasks; we’ll filter/sort in-memory to avoid schema changes.
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
                
                // Quick Add
                QuickAddBar(
                    title: $quickAddTitle,
                    onAdd: addQuickTask
                )
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Filter segmented control
                filterControl
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                
                // Content
                contentList
            }
            .navigationTitle("Todo")
            .toolbar {
                // Left: Sort/More menu
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
                
                // Right: Edit and Add
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
                
                // Bulk actions when selection is active
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
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
            .preferredColorScheme(appManager.isDark ? .dark : .light)
            .sheet(isPresented: $isPresentingEditor) {
                TaskEditorSheet(
                    title: editingItem?.title ?? "",
                    onCancel: { isPresentingEditor = false },
                    onSave: { title in
                        if let item = editingItem {
                            item.title = title
                        } else {
                            let new = TodoItem(title: title, isCompleted: false)
                            context.insert(new)
                        }
                        try? context.save()
                        isPresentingEditor = false
                    }
                )
                // Force a fresh instance so @State initializes with the right title
                .id(editingItem?.id ?? "new")
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        let total = allTodos.count
        let completed = allTodos.filter { $0.isCompleted }.count
        let progress = total == 0 ? 0 : Double(completed) / Double(total)
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Tasks")
                        .font(.title).bold()
                    Text("\(total) total • \(completed) done")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ProgressRing(progress: progress)
                    .frame(width: 44, height: 44)
                    .accessibilityLabel("Progress")
                    .accessibilityValue("\(Int(progress * 100)) percent")
            }
            .padding(.horizontal)
            .padding(.top, 10)
        }
        .padding(.bottom, 8)
        .background(
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(colorScheme == .dark ? 0.25 : 0.35),
                    Color.accentColor.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea(edges: .top)
        )
        .overlay(Divider(), alignment: .bottom)
    }
    
    // MARK: - Filter Control
    
    private var filterControl: some View {
        Picker("Filter", selection: $filter) {
            Text("All").tag(Filter.all)
            Text("Active").tag(Filter.active)
            Text("Done").tag(Filter.completed)
        }
        .pickerStyle(.segmented)
    }
    
    // MARK: - Content List
    
    private var contentList: some View {
        Group {
            if filteredSortedTodos.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checklist")
                        .font(.system(size: 56, weight: .light))
                        .foregroundStyle(.secondary)
                    Text("Nothing here")
                        .font(.headline)
                    Text("Add a task to get started.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selection) {
                    ForEach(filteredSortedTodos) { item in
                        TaskRow(
                            item: item,
                            onToggle: { toggleCompletion(item) }
                        )
                        .contentShape(Rectangle())
                        .tag(item.id)
                        .swipeActions(edge: HorizontalEdge.trailing, allowsFullSwipe: true) {
                            Button {
                                toggleCompletion(item)
                            } label: {
                                Label(item.isCompleted ? "Uncomplete" : "Complete",
                                      systemImage: item.isCompleted ? "xmark.circle" : "checkmark.circle.fill")
                            }
                            .tint(.green)
                            
                            Button(role: .destructive) {
                                delete(item)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button {
                                toggleCompletion(item)
                            } label: {
                                Label(item.isCompleted ? "Mark as Active" : "Mark as Done",
                                      systemImage: item.isCompleted ? "xmark.circle" : "checkmark.circle.fill")
                            }
                            Button {
                                editingItem = item
                                isPresentingEditor = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                delete(item)
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
    
    // MARK: - Derived Data
    
    private var filteredSortedTodos: [TodoItem] {
        var items = allTodos
        
        // Filter
        switch filter {
        case .all: break
        case .active:
            items = items.filter { !$0.isCompleted }
        case .completed:
            items = items.filter { $0.isCompleted }
        }
        
        // Search
        if !searchText.isEmpty {
            items = items.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
        
        // Sort
        switch sort {
        case .titleAsc:
            items.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .titleDesc:
            items.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending }
        case .status:
            // Active first, then done; then A–Z within groups.
            items.sort {
                if $0.isCompleted != $1.isCompleted {
                    return !$0.isCompleted && $1.isCompleted
                }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        }
        
        return items
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
    
    private func toggleCompletion(_ item: TodoItem) {
        item.isCompleted.toggle()
        try? context.save()
    }
    
    private func delete(_ item: TodoItem) {
        context.delete(item)
        try? context.save()
    }
    
    private func clearCompleted() {
        let completedItems = allTodos.filter { $0.isCompleted }
        completedItems.forEach { context.delete($0) }
        try? context.save()
    }
    
    private func bulkToggleComplete(_ completed: Bool) {
        let items = allTodos.filter { selection.contains($0.id) }
        for item in items {
            item.isCompleted = completed
        }
        try? context.save()
        selection.removeAll()
    }
    
    private func bulkDelete() {
        let items = allTodos.filter { selection.contains($0.id) }
        items.forEach { context.delete($0) }
        try? context.save()
        selection.removeAll()
    }
}

// MARK: - Types

private enum Filter: Int, CaseIterable {
    case all
    case active
    case completed
}

private enum Sort: Int, CaseIterable {
    case titleAsc
    case titleDesc
    case status
}

// MARK: - Components

private struct ProgressRing: View {
    let progress: Double
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.25), lineWidth: 6)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(progress * 100))%")
                .font(.caption2)
                .bold()
        }
        .animation(.easeInOut, value: progress)
    }
}

private struct QuickAddBar: View {
    @Binding var title: String
    var onAdd: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(Color.accentColor)
                .imageScale(.large)
            TextField("Add a new task", text: $title)
                .textFieldStyle(.roundedBorder)
                .onSubmit(onAdd)
            Button("Add") { onAdd() }
                .buttonStyle(.borderedProminent)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}

private struct TaskRow: View {
    let item: TodoItem
    var onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.isCompleted ? .green : .secondary)
                    .imageScale(.large)
            }
            .buttonStyle(.plain)
            
            Text(item.title)
                .strikethrough(item.isCompleted, color: .secondary)
                .foregroundStyle(item.isCompleted ? .secondary : .primary)
                .lineLimit(2)
            
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(item.isCompleted ? Color.secondary.opacity(0.12) : Color.secondary.opacity(0.08))
        )
        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
    }
}

// MARK: - Editor Sheet

private struct TaskEditorSheet: View {
    @State private var title: String
    let onCancel: () -> Void
    let onSave: (String) -> Void
    
    init(title: String, onCancel: @escaping () -> Void, onSave: @escaping (String) -> Void) {
        _title = State(initialValue: title)
        self.onCancel = onCancel
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.done)
                }
            }
            .navigationTitle("Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        onSave(trimmed)
                    }
                    .bold()
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    TodoScreen()
        .environmentObject(AppManager())
        .modelContainer(for: TodoItem.self, inMemory: true)
}
