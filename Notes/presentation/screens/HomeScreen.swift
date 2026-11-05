//
//  HomeScreen.swift
//  Notes
//
//  Created by Muhammad Khubaib Imtiaz on 19/10/2024.
//

import SwiftUI
import SwiftData
import CoreLocation
import MapKit

struct HomeScreen: View {
    
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var appManager: AppManager
    
    @Query private var allNotes: [NotesItem]
    @Query(sort: \NoteFolder.name) private var folders: [NoteFolder]
    
    /// Notes that aren't in Recently Deleted.
    private var notestList: [NotesItem] {
        allNotes.filter { !$0.isDeleted && !$0.isInTrash }
    }
    
    /// Notes in the folder being viewed (all notes when no folder is chosen).
    private var folderNotes: [NotesItem] {
        guard let id = selectedFolderID else { return notestList }
        return notestList.filter { $0.folder?.id == id }
    }
    
    private var selectedFolder: NoteFolder? {
        folders.first { $0.id == selectedFolderID }
    }
    
    private var trashCount: Int {
        allNotes.filter { !$0.isDeleted && $0.isInTrash }.count
    }
    
    // Folders & Recently Deleted
    @AppStorage("SelectedFolderID") private var storedFolderID: String = ""
    private var selectedFolderID: String? {
        storedFolderID.isEmpty ? nil : storedFolderID
    }
    @State private var showManageFolders = false
    @State private var showTrash = false
    @State private var showNewFolder = false
    @State private var newFolderName = ""
    
    /// A note opened from a widget.
    @State private var openedNote: NotesItem?
    
    /// The note open in the edit sheet.
    @State private var editingNote: NotesItem?
    
    // UI State
    @State private var searchText: String = ""
    @State private var selectedTag: String?
    @State private var layoutMode: LayoutMode = .grid
    @State private var sortMode: SortMode = .recent
    @State private var pushAdd: Bool = false
    
    // Quick filters
    @State private var filterImages: Bool = false
    @State private var filterVideo: Bool = false
    @State private var filterLocation: Bool = false
    
    // Derived data
    private var allTags: [String] {
        let tags = folderNotes.flatMap { $0.tags }
        return Array(Set(tags)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
    
    private var filteredAndSortedNotes: [NotesItem] {
        var items = folderNotes
        
        // Search
        if !searchText.isEmpty {
            items = items.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.desc.localizedCaseInsensitiveContains(searchText) ||
                $0.tags.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
            }
        }
        // Tag
        if let tag = selectedTag {
            items = items.filter { $0.tags.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) }
        }
        // Quick filters
        if filterImages {
            items = items.filter { ($0.images?.isEmpty == false) }
        }
        if filterVideo {
            items = items.filter { $0.playableVideoURL != nil }
        }
        if filterLocation {
            items = items.filter { $0.location != nil }
        }
        // Sort
        switch sortMode {
        case .recent:
            items.sort { $0.updatedAt > $1.updatedAt }
        case .title:
            items.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
        return items
    }
    
    private var pinnedNotes: [NotesItem] {
        filteredAndSortedNotes.filter { $0.isPinned }
    }
    private var otherNotes: [NotesItem] {
        filteredAndSortedNotes.filter { !$0.isPinned }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if filteredAndSortedNotes.isEmpty {
                    emptyState
                } else {
                    content
                }
            }
            // Tap the title to switch folders (like Mail and Files).
            .navigationTitle(selectedFolder?.name ?? String(localized: "Notes"))
            .navigationSubtitle(subtitle)
            .toolbarTitleMenu { folderMenuItems }
            .toolbar {
                // The title menu only opens from the small (scrolled) title,
                // so folders also get a visible button.
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        folderMenuItems
                    } label: {
                        Image(systemName: selectedFolder == nil ? "folder" : "folder.fill")
                    }
                    .accessibilityLabel("Folders")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    optionsMenu
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search notes")
            .overlay(alignment: .bottomTrailing) {
                FloatingAddButton {
                    pushAdd = true
                }
                .padding(.trailing, 20)
                .padding(.bottom, 24)
            }
            // One destination for every screen pushed from Home: several separate
            // navigationDestination modifiers on one screen can make SwiftUI loop forever.
            .navigationDestination(item: route) { route in
                switch route {
                case .newNote:
                    AddNotes(defaultFolder: selectedFolder)
                case .note(let note):
                    NotesDetail(notesItem: note)
                case .trash:
                    TrashScreen()
                }
            }
            .sheet(isPresented: $showManageFolders) {
                ManageFoldersSheet()
            }
            .alert("New Folder", isPresented: $showNewFolder) {
                TextField("Name", text: $newFolderName)
                Button("Cancel", role: .cancel) { newFolderName = "" }
                Button("Create") { createFolder() }
            } message: {
                Text("Enter a name for this folder.")
            }
            .onChange(of: folders.map(\.id)) { _, ids in
                // The folder being viewed was deleted (here or on another device).
                if let id = selectedFolderID, !ids.contains(id) { storedFolderID = "" }
            }
            .onChange(of: appManager.pendingRoute, initial: true) { _, route in
                handle(route)
            }
            .sheet(item: $editingNote) { note in
                NavigationStack {
                    AddNotes(editingNote: note)
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var subtitle: String {
        let count = folderNotes.count
        var text = count == 1 ? String(localized: "1 note") : String(localized: "\(count) notes")
        if activeFilterCount > 0 {
            text += String(localized: " · \(filteredAndSortedNotes.count) shown")
        }
        return text
    }
    
    private var activeFilterCount: Int {
        [filterImages, filterVideo, filterLocation].filter { $0 }.count + (selectedTag == nil ? 0 : 1)
    }
    
    /// Sort, layout and filters in one menu, instead of a row of buttons.
    private var optionsMenu: some View {
        Menu {
            Picker(selection: $layoutMode) {
                Label("Grid", systemImage: "square.grid.2x2").tag(LayoutMode.grid)
                Label("List", systemImage: "list.bullet").tag(LayoutMode.list)
            } label: {
                Text("View")
            }
            .pickerStyle(.inline)
            
            Picker(selection: $sortMode) {
                Label("Recently Edited", systemImage: "clock").tag(SortMode.recent)
                Label("Title", systemImage: "textformat").tag(SortMode.title)
            } label: {
                Text("Sort By")
            }
            .pickerStyle(.inline)
            
            Section("Show Only Notes With") {
                Toggle(isOn: $filterImages) { Label("Photos", systemImage: "photo") }
                Toggle(isOn: $filterVideo) { Label("Video", systemImage: "video") }
                Toggle(isOn: $filterLocation) { Label("Location", systemImage: "mappin") }
            }
            
            if activeFilterCount > 0 {
                Button(role: .destructive) {
                    filterImages = false
                    filterVideo = false
                    filterLocation = false
                    selectedTag = nil
                } label: {
                    Label("Clear Filters", systemImage: "xmark.circle")
                }
            }
        } label: {
            Image(systemName: activeFilterCount > 0
                  ? "line.3.horizontal.decrease.circle.fill"
                  : "line.3.horizontal.decrease.circle")
        }
        .accessibilityLabel("View options")
    }
    
    /// Which screen is pushed on top of Home, built from the individual flags.
    private var route: Binding<HomeRoute?> {
        Binding(
            get: {
                if pushAdd { return .newNote }
                if let openedNote { return .note(openedNote) }
                if showTrash { return .trash }
                return nil
            },
            set: { newValue in
                if newValue == nil {
                    pushAdd = false
                    openedNote = nil
                    showTrash = false
                }
            }
        )
    }
    
    /// Items of the title menu: folders, folder management and Recently Deleted.
    @ViewBuilder
    private var folderMenuItems: some View {
            Picker("Folder", selection: $storedFolderID) {
                Label("All Notes", systemImage: "tray.full").tag("")
                ForEach(folders) { folder in
                    Label("\(folder.name) (\(folder.activeNoteCount))", systemImage: "folder").tag(folder.id)
                }
            }
            Divider()
            Button {
                newFolderName = ""
                showNewFolder = true
            } label: {
                Label("New Folder…", systemImage: "folder.badge.plus")
            }
            if !folders.isEmpty {
                Button {
                    showManageFolders = true
                } label: {
                    Label("Manage Folders", systemImage: "folder.badge.gearshape")
                }
            }
            Divider()
            Button {
                showTrash = true
            } label: {
                Label(trashCount > 0 ? "Recently Deleted (\(trashCount))" : "Recently Deleted", systemImage: "trash")
            }
    }
    
    private func createFolder() {
        let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        newFolderName = ""
        guard !name.isEmpty else { return }
        if let existing = folders.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            storedFolderID = existing.id
            return
        }
        let folder = NoteFolder(name: String(name.prefix(40)))
        context.insert(folder)
        try? context.save()
        storedFolderID = folder.id
        Haptics.success()
    }
    
    // MARK: - Content
    
    private var content: some View {
        VStack(spacing: 0) {
            if layoutMode == .grid {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if !allTags.isEmpty {
                            tagFilterChips
                        }
                        if !pinnedNotes.isEmpty {
                            sectionHeader("Pinned", systemImage: "pin.fill")
                            grid(pinnedNotes)
                        }
                        if !otherNotes.isEmpty {
                            if !pinnedNotes.isEmpty {
                                sectionHeader("Notes", systemImage: nil)
                            }
                            grid(otherNotes)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                }
                .scrollIndicators(.hidden)
                // Room for the floating + button, so it never covers the last cards.
                .contentMargins(.bottom, 96, for: .scrollContent)
            } else {
                List {
                    if !allTags.isEmpty {
                        tagFilterChips
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                    if !pinnedNotes.isEmpty {
                        Section(header: Text("Pinned")) {
                            ForEach(pinnedNotes) { item in
                                NoteCard(item: item, style: .list, colorScheme: colorScheme)
                                    .contentShape(Rectangle())
                                    .background(
                                        NavigationLink("", destination: NotesDetail(notesItem: item))
                                            .opacity(0)
                                    )
                                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                                    .swipeActions(edge: .leading) { pinAction(for: item) }
                                    .swipeActions { editDeleteActions(for: item) }
                            }
                        }
                    }
                    
                    Section(header: Text("All Notes")) {
                        ForEach(otherNotes) { item in
                            NoteCard(item: item, style: .list, colorScheme: colorScheme)
                                .contentShape(Rectangle())
                                .background(
                                    NavigationLink("", destination: NotesDetail(notesItem: item))
                                        .opacity(0)
                                )
                                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                                .swipeActions(edge: .leading) { pinAction(for: item) }
                                .swipeActions { editDeleteActions(for: item) }
                        }
                        .onDelete(perform: deleteItems)
                    }
                }
                .listStyle(.insetGrouped)
                .contentMargins(.bottom, 96, for: .scrollContent)
            }
        }
        .animation(.easeInOut, value: layoutMode)
        .animation(.easeInOut, value: selectedTag)
        .animation(.easeInOut, value: sortMode)
        .animation(.easeInOut, value: filterImages)
        .animation(.easeInOut, value: filterVideo)
        .animation(.easeInOut, value: filterLocation)
    }
    
    private func sectionHeader(_ title: LocalizedStringKey, systemImage: String?) -> some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage).foregroundStyle(.orange)
            }
            Text(title)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.top, 4)
    }
    
    /// Two even columns (more on iPad); every card fills its column.
    private func grid(_ notes: [NotesItem]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12, alignment: .top)],
                  alignment: .leading, spacing: 12) {
            ForEach(notes) { item in
                NavigationLink {
                    NotesDetail(notesItem: item)
                } label: {
                    NoteCard(item: item, style: .grid, colorScheme: colorScheme)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button {
                        togglePin(for: item)
                    } label: {
                        Label(item.isPinned ? "Unpin" : "Pin", systemImage: item.isPinned ? "pin.slash" : "pin.fill")
                    }
                    Button {
                        presentEdit(for: item)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        deleteItem(item)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }
    
    private var tagFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Chip(title: String(localized: "All"), isSelected: selectedTag == nil) { selectedTag = nil }
                
                ForEach(allTags, id: \.self) { tag in
                    Chip(title: tag, isSelected: selectedTag == tag) {
                        if selectedTag == tag {
                            selectedTag = nil
                        } else {
                            selectedTag = tag
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "note.text")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(.secondary)
            
            if !searchText.isEmpty || activeFilterCount > 0, !folderNotes.isEmpty {
                Text("No matching notes")
                    .font(.title3).bold()
                Text("Try a different search or clear the filters.")
                    .foregroundStyle(.secondary)
            } else {
                Text(selectedFolder == nil ? "No notes yet" : "No notes in \(selectedFolder?.name ?? "")")
                    .font(.title3).bold()
                Text("Tap + to write your first note.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func pinAction(for item: NotesItem) -> some View {
        Button {
            togglePin(for: item)
        } label: {
            Label(item.isPinned ? LocalizedStringKey("Unpin") : LocalizedStringKey("Pin"),
                  systemImage: item.isPinned ? "pin.slash.fill" : "pin.fill")
        }
        .tint(.orange)
    }
    
    private func editDeleteActions(for item: NotesItem) -> some View {
        Group {
            Button {
                presentEdit(for: item)
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
            
            Button(role: .destructive) {
                deleteItem(item)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private func togglePin(for note: NotesItem) {
        note.isPinned.toggle()
        note.updatedAt = Date()
        try? context.save()
        Haptics.tap(.medium)
    }
    
    /// Opens a new note or a specific note when a widget, control or Siri asks.
    private func handle(_ route: AppRoute?) {
        switch route {
        case .newNote:
            openedNote = nil
            pushAdd = true
            appManager.pendingRoute = nil
        case .note(let id):
            pushAdd = false
            openedNote = notestList.first { $0.id == id }
            appManager.pendingRoute = nil
        case .todos, .todo, nil:
            break
        }
    }
    
    private func presentEdit(for item: NotesItem) {
        editingNote = item
    }
    
    private func deleteItems(_ offsets: IndexSet) {
        let items = otherNotes
        for idx in offsets {
            deleteItem(items[idx])
        }
    }
    
    /// Moves the note to Recently Deleted, where it can be restored for 30 days.
    private func deleteItem(_ item: NotesItem) {
        NoteTrash.moveToTrash(item, context: context)
        Haptics.warning()
    }
}

// MARK: - Navigation

private enum HomeRoute: Hashable {
    case newNote
    case note(NotesItem)
    case trash
}

// MARK: - Layout & Sort Modes

private enum LayoutMode: Int, CaseIterable {
    case list
    case grid
    
    mutating func toggle() {
        self = (self == .grid) ? .list : .grid
    }
}

private enum SortMode: Int, CaseIterable {
    case recent
    case title
}

// MARK: - Components

private struct FloatingAddButton: View {
    var action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(Color.accentColor)
                        .shadow(color: .black.opacity(colorScheme == .dark ? 0.5 : 0.2), radius: 8, x: 0, y: 4)
                )
        }
        .accessibilityLabel("New Note")
    }
}

private struct Chip: View {
    let title: String
    var isSelected: Bool = false
    var systemImage: String? = nil
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.15)))
        }
        .buttonStyle(.plain)
    }
}

private struct NoteCard: View {
    let item: NotesItem
    let style: Style
    let colorScheme: ColorScheme
    @AppStorage("ShowPreview") private var showPreview = true
    
    enum Style {
        case list
        case grid
        case pinned
    }
    
    var body: some View {
        // A note deleted elsewhere (e.g. Reset All Data) can still be rendered once
        // before the query refreshes; reading its properties then would crash.
        if item.isDeleted || item.modelContext == nil {
            EmptyView()
        } else {
            cardContent
        }
    }
    
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            mediaHeader
            
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                if item.isPinned {
                    Spacer(minLength: 0)
                    Image(systemName: "pin.fill")
                        .foregroundColor(.orange)
                        .imageScale(.small)
                        .accessibilityLabel("Pinned")
                }
            }
            
            if !item.tags.isEmpty {
                TagsChipsView(tags: item.tags, limit: 3)
            }
            
            if showPreview && !item.desc.isEmpty {
                Text(item.desc)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(item.images?.isEmpty == false ? 2 : 4)
                    .multilineTextAlignment(.leading)
            }
            
            if !item.checklist.isEmpty {
                checklistSummary
            }
            
            HStack(spacing: 10) {
                if item.location != nil {
                    Label("", systemImage: "mappin.circle")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.blue)
                        .imageScale(.small)
                }
                if let reminder = item.reminderDate, reminder > Date() {
                    Label("", systemImage: "bell.fill")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.orange)
                        .imageScale(.small)
                        .accessibilityLabel("Reminder set")
                }
                if item.playableVideoURL != nil {
                    Label("", systemImage: "video.fill")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.purple)
                        .imageScale(.small)
                }
                Spacer()
                Text(Self.shortDate(item.updatedAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.06))
        )
    }
    
    /// "9:41 AM" today, "Yesterday", a weekday this week, otherwise "Nov 3".
    static func shortDate(_ date: Date, now: Date = Date()) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        if calendar.isDateInYesterday(date) {
            return String(localized: "Yesterday")
        }
        if let days = calendar.dateComponents([.day], from: date, to: now).day, days < 7 {
            return date.formatted(.dateTime.weekday(.wide))
        }
        if calendar.isDate(date, equalTo: now, toGranularity: .year) {
            return date.formatted(.dateTime.month(.abbreviated).day())
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
    
    private var cardBackground: some ShapeStyle {
        if let tint = item.noteColor?.color {
            return AnyShapeStyle(LinearGradient(colors: [
                tint.opacity(colorScheme == .dark ? 0.40 : 0.30),
                tint.opacity(0.10)
            ], startPoint: .topLeading, endPoint: .bottomTrailing))
        } else if item.isPinned {
            return AnyShapeStyle(LinearGradient(colors: [
                Color.orange.opacity(colorScheme == .dark ? 0.35 : 0.25),
                Color.orange.opacity(0.08)
            ], startPoint: .topLeading, endPoint: .bottomTrailing))
        } else {
            return AnyShapeStyle(Color(.secondarySystemGroupedBackground))
        }
    }
    
    @ViewBuilder
    private var mediaHeader: some View {
        if let images = item.images, let first = images.first, let ui = UIImage(data: first) {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(height: style == .list ? 120 : 110)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .overlay(alignment: .bottomLeading) {
                        LinearGradient(colors: [.black.opacity(0.0), .black.opacity(0.35)], startPoint: .center, endPoint: .bottom)
                            .frame(height: 40)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                
                if images.count > 1 {
                    Text("+\(images.count - 1)")
                        .font(.caption2).bold()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(.thinMaterial))
                        .padding(6)
                }
            }
        }
    }
    
    @ViewBuilder
    private var checklistSummary: some View {
        let total = item.checklist.count
        let done = item.checklist.filter { $0.isDone }.count
        let progress = total == 0 ? 0 : Double(done) / Double(total)
        
        HStack(spacing: 6) {
            Image(systemName: done == total ? "checkmark.circle.fill" : "checklist")
                .foregroundColor(done == total ? .green : .secondary)
                .imageScale(.small)
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(done == total ? .green : .accentColor)
            Text("\(done)/\(total)")
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(done) of \(total) checklist items done")
    }
}

#Preview {
    HomeScreen()
        .environmentObject(AppManager())
        .modelContainer(for: NotesItem.self, inMemory: true)
}

// Simple tags chips view reused
private struct TagsChipsView: View {
    let tags: [String]
    let limit: Int
    
    init(tags: [String], limit: Int = 4) {
        self.tags = tags
        self.limit = limit
    }
    
    var body: some View {
        let shown = Array(tags.prefix(limit))
        HStack(spacing: 6) {
            ForEach(shown, id: \.self) { tag in
                Text(tag)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.blue.opacity(0.15)))
                    .foregroundColor(.blue)
            }
            if tags.count > shown.count {
                Text("+\(tags.count - shown.count)")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.secondary.opacity(0.15)))
                    .foregroundColor(.secondary)
            }
        }
    }
}
