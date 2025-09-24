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
    
    @Query private var notestList: [NotesItem]
    
    @State private var selectedItem: NotesItem?
    @State private var isSheetExpanded: Bool = false
    
    // Add / Edit bindings
    @State private var notesTitle: String = ""
    @State private var notesDesc: String = ""
    @State private var navTitle: String = "Add Notes"
    
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var selectedLocationName: String = "No Location Selected"
    
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
        let tags = notestList.flatMap { $0.tags }
        return Array(Set(tags)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
    
    private var filteredAndSortedNotes: [NotesItem] {
        var items = notestList
        
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
            items = items.filter { $0.videoURL != nil }
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
            .navigationTitle(LocalizedStringKey("Notes"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Picker("", selection: $sortMode) {
                        Label("Recent", systemImage: "clock.arrow.circlepath").tag(SortMode.recent)
                        Label("Title", systemImage: "textformat").tag(SortMode.title)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 220)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                layoutMode.toggle()
                            }
                        } label: {
                            Image(systemName: layoutMode == .grid ? "list.bullet" : "square.grid.2x2")
                        }
                        
                        NavigationLink {
                            AddNotes(
                                title: $notesTitle,
                                desc: $notesDesc,
                                navTitle: $navTitle,
                                onSave: { resetAddState() }
                            )
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .imageScale(.large)
                        }
                        .accessibilityLabel("New Note")
                    }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            // The header is now inset into the safe area so it pushes content down (no overlap).
            .safeAreaInset(edge: .top, spacing: 0) {
                header
                    .background(
                        LinearGradient(
                            colors: [
                                Color.accentColor.opacity(colorScheme == .dark ? 0.25 : 0.35),
                                Color.accentColor.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .ignoresSafeArea(edges: .top)
                    )
                    .overlay(
                        Divider()
                            .offset(y: 0.5),
                        alignment: .bottom
                    )
            }
            .overlay(alignment: .bottomTrailing) {
                FloatingAddButton {
                    pushAdd = true
                }
                .padding(.trailing, 20)
                .padding(.bottom, 24)
            }
            .navigationDestination(isPresented: $pushAdd) {
                AddNotes(
                    title: $notesTitle,
                    desc: $notesDesc,
                    navTitle: $navTitle,
                    onSave: { resetAddState() }
                )
            }
            .sheet(isPresented: $isSheetExpanded, onDismiss: { resetEditState() }) {
                UpdateNotes(
                    title: $notesTitle,
                    desc: $notesDesc,
                    navTitle: $navTitle,
                    selectedLocation: $selectedLocation,
                    selectedLocationName: $selectedLocationName,
                    onSave: {
                        if let selectedItem = selectedItem {
                            selectedItem.title = notesTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                            selectedItem.desc = notesDesc.trimmingCharacters(in: .whitespacesAndNewlines)
                            selectedItem.location = selectedLocation
                            selectedItem.updatedAt = Date()
                            try? context.save()
                        }
                        isSheetExpanded = false
                        resetEditState()
                    }
                )
            }
        }
    }
    
    // MARK: - Header (Safe Area Inset)
    
    private var header: some View {
        VStack(spacing: 10) {
            // Hero stats + quick filters
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Notes")
                        .font(.title).bold()
                    Text("\(notestList.count) total • \(pinnedNotes.count) pinned")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 10) {
                    quickFilterButton("photo.on.rectangle", isOn: $filterImages)
                    quickFilterButton("video.fill", isOn: $filterVideo)
                    quickFilterButton("mappin.circle.fill", isOn: $filterLocation)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            // Tags chips
            tagFilterChips
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        }
    }
    
    private func quickFilterButton(_ systemName: String, isOn: Binding<Bool>) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                isOn.wrappedValue.toggle()
            }
        } label: {
            Image(systemName: systemName)
                .imageScale(.medium)
                .foregroundStyle(isOn.wrappedValue ? .white : .primary)
                .padding(8)
                .background(
                    Circle().fill(isOn.wrappedValue ? Color.accentColor : Color.secondary.opacity(0.15))
                )
        }
    }
    
    // MARK: - Content
    
    private var content: some View {
        VStack(spacing: 0) {
            if layoutMode == .grid {
                ScrollView {
                    VStack(spacing: 12) {
                        if !pinnedNotes.isEmpty {
                            pinnedHorizontalSection
                        }
                        gridSection
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                    }
                }
                .scrollIndicators(.hidden)
            } else {
                List {
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
            }
        }
        .animation(.easeInOut, value: layoutMode)
        .animation(.easeInOut, value: selectedTag)
        .animation(.easeInOut, value: sortMode)
        .animation(.easeInOut, value: filterImages)
        .animation(.easeInOut, value: filterVideo)
        .animation(.easeInOut, value: filterLocation)
    }
    
    private var pinnedHorizontalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Pinned", systemImage: "pin.fill")
                    .foregroundStyle(.orange)
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(pinnedNotes) { item in
                        NavigationLink {
                            NotesDetail(notesItem: item)
                        } label: {
                            NoteCard(item: item, style: .pinned, colorScheme: colorScheme)
                                .frame(width: 260)
                        }
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
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
        }
        .padding(.top, 8)
    }
    
    private var gridSection: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
            ForEach(otherNotes) { item in
                NavigationLink {
                    NotesDetail(notesItem: item)
                } label: {
                    NoteCard(item: item, style: .grid, colorScheme: colorScheme)
                }
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
                Chip(
                    title: "All",
                    isSelected: selectedTag == nil,
                    systemImage: selectedTag == nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle"
                ) { selectedTag = nil }
                
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
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "note.text")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(.secondary)
            
            Text("No notes yet")
                .font(.title3).bold()
            Text("Tap the + button to create your first note. Add images, tags, a checklist, a location and more.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)
            
            Button {
                pushAdd = true
            } label: {
                Label("New Note", systemImage: "plus")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.accentColor.opacity(0.15)))
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
        if let index = notestList.firstIndex(where: { $0.id == note.id }) {
            notestList[index].isPinned.toggle()
            notestList[index].updatedAt = Date()
            try? context.save()
        }
    }
    
    private func presentEdit(for item: NotesItem) {
        selectedItem = item
        notesTitle = item.title
        notesDesc = item.desc
        selectedLocation = item.location
        navTitle = "Update Note"
        isSheetExpanded = true
    }
    
    private func deleteItems(_ offsets: IndexSet) {
        let items = otherNotes
        for idx in offsets {
            deleteItem(items[idx])
        }
    }
    
    private func deleteItem(_ item: NotesItem) {
        context.delete(item)
        try? context.save()
    }
    
    private func resetAddState() {
        // reset fields back to default for next add
        notesTitle = ""
        notesDesc = ""
        navTitle = "Add Notes"
        selectedLocation = nil
        selectedLocationName = "No Location Selected"
    }
    
    private func resetEditState() {
        selectedItem = nil
        notesTitle = ""
        notesDesc = ""
        navTitle = "Add Notes"
        selectedLocation = nil
        selectedLocationName = "No Location Selected"
        isSheetExpanded = false
    }
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
    
    enum Style {
        case list
        case grid
        case pinned
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            mediaHeader
            
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(1)
                
                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .foregroundColor(.orange)
                        .imageScale(.small)
                        .padding(.leading, 2)
                }
            }
            
            if !item.tags.isEmpty {
                TagsChipsView(tags: item.tags, limit: 3)
            }
            
            if !item.desc.isEmpty {
                Text(item.desc)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
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
                if item.videoURL != nil {
                    Label("", systemImage: "video.fill")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.purple)
                        .imageScale(.small)
                }
                Spacer()
                Text(item.updatedAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.08), radius: 8, x: 0, y: 4)
    }
    
    private var cardBackground: some ShapeStyle {
        if item.isPinned {
            return AnyShapeStyle(LinearGradient(colors: [
                Color.orange.opacity(colorScheme == .dark ? 0.35 : 0.25),
                Color.orange.opacity(0.08)
            ], startPoint: .topLeading, endPoint: .bottomTrailing))
        } else {
            return AnyShapeStyle(.regularMaterial)
        }
    }
    
    @ViewBuilder
    private var mediaHeader: some View {
        if let images = item.images, let first = images.first, let ui = UIImage(data: first) {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(height: style == .list ? 120 : 100)
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
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.12))
                .frame(height: style == .list ? 80 : 80)
                .overlay(
                    Image(systemName: "note.text")
                        .foregroundStyle(.secondary)
                )
        }
    }
    
    @ViewBuilder
    private var checklistSummary: some View {
        let total = item.checklist.count
        let done = item.checklist.filter { $0.isDone }.count
        let progress = total == 0 ? 0 : Double(done) / Double(total)
        
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: done == total ? "checkmark.circle.fill" : "checkmark.circle")
                    .foregroundColor(done == total ? .green : .gray)
                    .imageScale(.small)
                Text("\(done)/\(total) completed")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            ProgressView(value: progress)
                .progressViewStyle(.linear)
        }
    }
}

#Preview {
    HomeScreen()
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
