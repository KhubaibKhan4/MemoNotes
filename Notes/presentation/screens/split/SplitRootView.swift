//
//  SplitRootView.swift
//  The iPad and Mac layout: a sidebar of folders and sections, a note list,
//  and the open note side by side (like Notes and Mail). iPhone keeps the tab bar.
//

import SwiftUI
import SwiftData

/// What the sidebar has selected.
enum SidebarItem: Hashable {
    case allNotes
    case folder(String)
    case trash
    case tasks
    case settings

    /// Sections that show a note list and an open note (three columns).
    var showsNotes: Bool {
        switch self {
        case .allNotes, .folder: true
        default: false
        }
    }
}

struct SplitRootView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var appManager: AppManager

    @Query(sort: \NoteFolder.name) private var folders: [NoteFolder]
    @Query private var allNotes: [NotesItem]
    @Query(filter: #Predicate<TodoItem> { !$0.isCompleted }) private var openTodos: [TodoItem]

    @State private var selection: SidebarItem? = .allNotes
    @State private var selectedNoteID: String?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showNewNote = false
    /// A just-saved note to select once it shows up in the note list.
    @State private var pendingNoteID: String?

    // Folder editing from the sidebar.
    @State private var showNewFolder = false
    @State private var newFolderName = ""
    @State private var renaming: NoteFolder?
    @State private var renameText = ""
    @State private var folderToDelete: NoteFolder?

    private var liveNotes: [NotesItem] {
        allNotes.filter { !$0.isDeleted && $0.modelContext != nil }
    }
    private var activeNoteCount: Int { liveNotes.filter { !$0.isInTrash }.count }
    private var trashCount: Int { liveNotes.filter { $0.isInTrash }.count }

    private var currentFolder: NoteFolder? {
        if case .folder(let id) = selection { return folders.first { $0.id == id } }
        return nil
    }

    private var selectedNote: NotesItem? {
        guard let selectedNoteID else { return nil }
        return liveNotes.first { $0.id == selectedNoteID && !$0.isInTrash }
    }

    var body: some View {
        Group {
            if selection?.showsNotes ?? true {
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    sidebar
                } content: {
                    NotesListColumn(
                        folder: currentFolder,
                        selectedNoteID: $selectedNoteID,
                        pendingNoteID: $pendingNoteID,
                        onNewNote: { showNewNote = true }
                    )
                } detail: {
                    noteDetail
                }
            } else {
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    sidebar
                } detail: {
                    otherDetail
                }
            }
        }
        .sheet(isPresented: $showNewNote) {
            NavigationStack {
                AddNotes(defaultFolder: currentFolder) { noteID in
                    // Select it in the list once the list has it, so the
                    // highlighted row and the open note always match.
                    pendingNoteID = noteID
                }
            }
            .presentationSizing(.page)
        }
        .onChange(of: selection) { _, newValue in
            // Keep the open note only if it's still in the list being shown.
            guard let note = selectedNote else { return }
            if case .folder(let id) = newValue, note.folder?.id != id {
                selectedNoteID = nil
            }
        }
        .onChange(of: folders.map(\.id)) { _, ids in
            // The folder being viewed was deleted (here or on another device).
            if case .folder(let id) = selection, !ids.contains(id) { selection = .allNotes }
        }
        .onChange(of: appManager.pendingRoute, initial: true) { _, route in
            handle(route)
        }
        .alert("New Folder", isPresented: $showNewFolder) {
            TextField("Name", text: $newFolderName)
            Button("Cancel", role: .cancel) { newFolderName = "" }
            Button("Create") { createFolder() }
        } message: {
            Text("Enter a name for this folder.")
        }
        .alert("Rename Folder", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) { renaming = nil }
            Button("Save") { saveRename() }
        }
        .confirmationDialog(
            "Delete “\(folderToDelete?.name ?? "")”?",
            isPresented: Binding(get: { folderToDelete != nil }, set: { if !$0 { folderToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete Folder", role: .destructive) { deleteFolder() }
        } message: {
            Text("Its notes won't be deleted. They'll stay in All Notes.")
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selection) {
            Section("Notes") {
                Label("All Notes", systemImage: "tray.full")
                    .badge(activeNoteCount)
                    .tag(SidebarItem.allNotes)

                ForEach(folders) { folder in
                    Label(folder.name, systemImage: "folder")
                        .badge(folder.activeNoteCount)
                        .tag(SidebarItem.folder(folder.id))
                        .contextMenu {
                            Button {
                                renameText = folder.name
                                renaming = folder
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                folderToDelete = folder
                            } label: {
                                Label("Delete Folder", systemImage: "trash")
                            }
                        }
                }

                Label("Recently Deleted", systemImage: "trash")
                    .badge(trashCount)
                    .tag(SidebarItem.trash)
            }

            Section {
                Label("Todo", systemImage: "checklist")
                    .badge(openTodos.count)
                    .tag(SidebarItem.tasks)
                Label("Settings", systemImage: "gear")
                    .tag(SidebarItem.settings)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("CloudNote AI")
        .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        .safeAreaInset(edge: .bottom) {
            Button {
                newFolderName = ""
                showNewFolder = true
            } label: {
                Label("New Folder", systemImage: "folder.badge.plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        // Keep "New Folder" at the bottom of the sidebar when the keyboard is up.
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    // MARK: - Detail

    @ViewBuilder
    private var noteDetail: some View {
        if let note = selectedNote {
            NavigationStack {
                NotesDetail(notesItem: note)
            }
            // A fresh detail per note, so its map, photos and sheets don't carry over.
            .id(note.id)
        } else {
            ContentUnavailableView {
                Label("No Note Selected", systemImage: "note.text")
            } description: {
                Text("Select a note to read it here.")
            } actions: {
                Button {
                    showNewNote = true
                } label: {
                    Label("New Note", systemImage: "square.and.pencil")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    @ViewBuilder
    private var otherDetail: some View {
        switch selection {
        case .trash:
            NavigationStack { TrashScreen() }
        case .tasks:
            TodoScreen()
        case .settings:
            SettingScreen()
        default:
            EmptyView()
        }
    }

    // MARK: - Actions

    /// Widgets, Siri, Spotlight and reminders open a note or a task.
    private func handle(_ route: AppRoute?) {
        switch route {
        case .newNote:
            showNewNote = true
            appManager.pendingRoute = nil
        case .note(let id):
            if let note = liveNotes.first(where: { $0.id == id }) {
                selection = note.folder.map { .folder($0.id) } ?? .allNotes
                selectedNoteID = id
            }
            appManager.pendingRoute = nil
        case .todos:
            selection = .tasks
            appManager.pendingRoute = nil
        case .todo:
            // TodoScreen opens the task itself once it's on screen.
            selection = .tasks
        case nil:
            break
        }
    }

    private func createFolder() {
        let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        newFolderName = ""
        guard !name.isEmpty else { return }
        if let existing = folders.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            selection = .folder(existing.id)
            return
        }
        let folder = NoteFolder(name: String(name.prefix(40)))
        context.insert(folder)
        try? context.save()
        selection = .folder(folder.id)
    }

    private func saveRename() {
        let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let folder = renaming, !name.isEmpty {
            folder.name = String(name.prefix(40))
            try? context.save()
        }
        renaming = nil
    }

    private func deleteFolder() {
        guard let folder = folderToDelete else { return }
        if case .folder(let id) = selection, id == folder.id { selection = .allNotes }
        context.delete(folder)
        try? context.save()
        folderToDelete = nil
    }
}

// MARK: - Note list (middle column)

private struct NotesListColumn: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \NoteFolder.name) private var folders: [NoteFolder]
    @Query private var allNotes: [NotesItem]

    /// The folder being shown, or `nil` for All Notes.
    let folder: NoteFolder?
    @Binding var selectedNoteID: String?
    /// A just-saved note waiting to be selected once it's in this list.
    @Binding var pendingNoteID: String?
    var onNewNote: () -> Void

    @State private var searchText = ""
    @AppStorage("SplitSortByTitle") private var sortByTitle = false

    private var notes: [NotesItem] {
        var items = allNotes.filter { !$0.isDeleted && $0.modelContext != nil && !$0.isInTrash }
        if let folder {
            items = items.filter { $0.folder?.id == folder.id }
        }
        if !searchText.isEmpty {
            items = items.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.desc.localizedCaseInsensitiveContains(searchText) ||
                $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        if sortByTitle {
            items.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        } else {
            items.sort { $0.updatedAt > $1.updatedAt }
        }
        return items
    }

    var body: some View {
        let notes = notes
        let pinned = notes.filter(\.isPinned)
        let others = notes.filter { !$0.isPinned }

        List(selection: $selectedNoteID) {
            if !pinned.isEmpty {
                Section {
                    rows(pinned)
                } header: {
                    Label("Pinned", systemImage: "pin.fill")
                }
            }
            if !others.isEmpty {
                Section {
                    rows(others)
                } header: {
                    if !pinned.isEmpty { Text("Notes") }
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if notes.isEmpty {
                if searchText.isEmpty {
                    // The New Note button lives in the toolbar and the empty note pane.
                    ContentUnavailableView(
                        folder == nil
                            ? LocalizedStringKey("No notes yet")
                            : LocalizedStringKey("No notes in \(folder?.name ?? "")"),
                        systemImage: "note.text"
                    )
                } else {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
        .navigationTitle(folder?.name ?? String(localized: "All Notes"))
        .navigationSubtitle(notes.count == 1 ? String(localized: "1 note") : String(localized: "\(notes.count) notes"))
        .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 440)
        .searchable(text: $searchText, prompt: "Search notes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                // ⌘N comes from the app's File menu command.
                Button(action: onNewNote) {
                    Label("New Note", systemImage: "square.and.pencil")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Picker(selection: $sortByTitle) {
                    Label("Recently Edited", systemImage: "clock").tag(false)
                    Label("Title", systemImage: "textformat").tag(true)
                } label: {
                    Label("Sort By", systemImage: "arrow.up.arrow.down")
                }
                .pickerStyle(.menu)
            }
        }
        .onChange(of: notes.map(\.id)) { _, ids in
            if selectPendingNote(in: ids) { return }
            // The open note was deleted or moved out of this folder.
            if let id = selectedNoteID, !ids.contains(id) { selectedNoteID = nil }
        }
        .onChange(of: pendingNoteID) { _, newValue in
            guard newValue != nil else { return }
            // A search could hide the new note; show the whole list again.
            searchText = ""
            selectPendingNote(in: notes.map(\.id))
        }
    }

    /// Selects the just-saved note once the list contains it.
    /// Returns `true` when it did.
    @discardableResult
    private func selectPendingNote(in ids: [String]) -> Bool {
        guard let pending = pendingNoteID, ids.contains(pending) else { return false }
        pendingNoteID = nil
        selectedNoteID = pending
        return true
    }

    private func rows(_ notes: [NotesItem]) -> some View {
        ForEach(notes) { note in
            NoteRow(note: note, showsFolder: folder == nil)
                .tag(note.id)
                .swipeActions(edge: .leading) {
                    Button {
                        togglePin(note)
                    } label: {
                        Label(note.isPinned ? "Unpin" : "Pin", systemImage: note.isPinned ? "pin.slash.fill" : "pin.fill")
                    }
                    .tint(.orange)
                }
                .swipeActions {
                    Button(role: .destructive) {
                        delete(note)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .contextMenu { menu(for: note) }
        }
    }

    @ViewBuilder
    private func menu(for note: NotesItem) -> some View {
        Button {
            togglePin(note)
        } label: {
            Label(note.isPinned ? "Unpin" : "Pin", systemImage: note.isPinned ? "pin.slash" : "pin")
        }
        Menu {
            Picker("Folder", selection: Binding(
                get: { note.folder?.id ?? "" },
                set: { id in move(note, toFolderID: id) }
            )) {
                Label("None", systemImage: "tray").tag("")
                ForEach(folders) { folder in
                    Label(folder.name, systemImage: "folder").tag(folder.id)
                }
            }
        } label: {
            Label("Folder", systemImage: "folder")
        }
        ShareLink(item: NoteShare.plainText(for: note)) {
            Label("Share Note", systemImage: "square.and.arrow.up")
        }
        Divider()
        Button(role: .destructive) {
            delete(note)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func togglePin(_ note: NotesItem) {
        note.isPinned.toggle()
        note.updatedAt = Date()
        try? context.save()
        Haptics.tap(.medium)
    }

    private func move(_ note: NotesItem, toFolderID id: String) {
        note.folder = folders.first { $0.id == id }
        note.updatedAt = Date()
        try? context.save()
    }

    private func delete(_ note: NotesItem) {
        if selectedNoteID == note.id { selectedNoteID = nil }
        NoteTrash.moveToTrash(note, context: context)
        Haptics.warning()
    }
}

// MARK: - Row

/// A compact list row: title, date and first line, a color strip and a photo thumbnail.
private struct NoteRow: View {
    let note: NotesItem
    var showsFolder: Bool

    var body: some View {
        if note.isDeleted || note.modelContext == nil {
            EmptyView()
        } else {
            content
        }
    }

    private var content: some View {
        HStack(alignment: .center, spacing: 12) {
            if let tint = note.noteColor?.color {
                Capsule()
                    .fill(tint)
                    .frame(width: 4)
                    .padding(.vertical, 2)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(note.title.isEmpty ? String(localized: "New Note") : note.title)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(NoteCard.shortDate(note.updatedAt))
                        .foregroundStyle(.primary.opacity(0.7))
                    Text(previewLine)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .font(.subheadline)

                if showsFolder, let folder = note.folder {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                        Text(folder.name)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            if let data = note.images?.first, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    /// First line of the body, or a checklist summary when there's no text.
    private var previewLine: String {
        let firstLine = note.desc
            .split(whereSeparator: \.isNewline)
            .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if let firstLine { return String(firstLine) }
        let items = note.checklist
        if !items.isEmpty {
            let done = items.filter(\.isDone).count
            return String(localized: "\(done)/\(items.count) completed")
        }
        return ""
    }
}
