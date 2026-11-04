//
//  FolderScreens.swift
//  Notes
//
//  Recently Deleted and folder management.
//

import SwiftUI
import SwiftData

// MARK: - Recently Deleted

struct TrashScreen: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<NotesItem> { $0.deletedAt != nil }, sort: \NotesItem.deletedAt, order: .reverse)
    private var trashed: [NotesItem]

    @State private var confirmEmpty = false
    @State private var noteToDelete: NotesItem?

    private var visible: [NotesItem] { trashed.filter { !$0.isDeleted } }

    var body: some View {
        Group {
            if visible.isEmpty {
                ContentUnavailableView(
                    "No Recently Deleted Notes",
                    systemImage: "trash",
                    description: Text("Notes you delete stay here for \(NoteTrash.keepDays) days before they're removed.")
                )
            } else {
                List {
                    Section {
                        ForEach(visible) { note in
                            row(note)
                                .swipeActions(edge: .leading) {
                                    Button {
                                        restore(note)
                                    } label: {
                                        Label("Restore", systemImage: "arrow.uturn.backward")
                                    }
                                    .tint(.green)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        noteToDelete = note
                                    } label: {
                                        Label("Delete Now", systemImage: "trash")
                                    }
                                }
                                .contextMenu {
                                    Button {
                                        restore(note)
                                    } label: {
                                        Label("Restore", systemImage: "arrow.uturn.backward")
                                    }
                                    Button(role: .destructive) {
                                        noteToDelete = note
                                    } label: {
                                        Label("Delete Now", systemImage: "trash")
                                    }
                                }
                        }
                    } footer: {
                        Text("Swipe right to restore a note. Notes are removed for good after \(NoteTrash.keepDays) days.")
                    }
                }
            }
        }
        .navigationTitle("Recently Deleted")
        .toolbar {
            if !visible.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Empty", role: .destructive) { confirmEmpty = true }
                }
            }
        }
        .confirmationDialog(
            "Delete \(visible.count == 1 ? "this note" : "all \(visible.count) notes") for good?",
            isPresented: $confirmEmpty,
            titleVisibility: .visible
        ) {
            Button("Delete All", role: .destructive) { emptyTrash() }
        } message: {
            Text("This can't be undone.")
        }
        .confirmationDialog(
            "Delete this note for good?",
            isPresented: Binding(get: { noteToDelete != nil }, set: { if !$0 { noteToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete Now", role: .destructive) {
                if let note = noteToDelete {
                    NoteTrash.deletePermanently(note, context: context)
                    Haptics.warning()
                }
                noteToDelete = nil
            }
        } message: {
            Text("This can't be undone.")
        }
    }

    private func row(_ note: NotesItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.title).font(.headline).lineLimit(1)
            if !note.desc.isEmpty {
                Text(note.desc).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            }
            let days = NoteTrash.daysLeft(for: note)
            Text(days == 0 ? "Removed soon" : "\(days) day\(days == 1 ? "" : "s") left")
                .font(.caption)
                .foregroundStyle(days <= 3 ? .red : .secondary)
        }
        .padding(.vertical, 2)
    }

    private func restore(_ note: NotesItem) {
        NoteTrash.restore(note, context: context)
        Haptics.success()
    }

    private func emptyTrash() {
        for note in visible {
            NoteTrash.deletePermanently(note, context: context)
        }
        Haptics.warning()
    }
}

// MARK: - Manage folders

struct ManageFoldersSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \NoteFolder.name) private var folders: [NoteFolder]

    @State private var renaming: NoteFolder?
    @State private var renameText = ""
    @State private var folderToDelete: NoteFolder?
    @State private var showNew = false
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(folders) { folder in
                        HStack {
                            Label(folder.name, systemImage: "folder")
                            Spacer()
                            Text("\(folder.activeNoteCount)")
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { startRename(folder) }
                        .swipeActions {
                            Button(role: .destructive) {
                                folderToDelete = folder
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                startRename(folder)
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                } footer: {
                    Text("Tap a folder to rename it. Deleting a folder keeps its notes in All Notes.")
                }

                Section {
                    Button {
                        newName = ""
                        showNew = true
                    } label: {
                        Label("New Folder", systemImage: "folder.badge.plus")
                    }
                }
            }
            .navigationTitle("Folders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Rename Folder", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
                TextField("Name", text: $renameText)
                Button("Cancel", role: .cancel) { renaming = nil }
                Button("Save") { saveRename() }
            }
            .alert("New Folder", isPresented: $showNew) {
                TextField("Name", text: $newName)
                Button("Cancel", role: .cancel) { }
                Button("Create") { createFolder() }
            }
            .confirmationDialog(
                "Delete “\(folderToDelete?.name ?? "")”?",
                isPresented: Binding(get: { folderToDelete != nil }, set: { if !$0 { folderToDelete = nil } }),
                titleVisibility: .visible
            ) {
                Button("Delete Folder", role: .destructive) {
                    if let folder = folderToDelete {
                        context.delete(folder)
                        try? context.save()
                    }
                    folderToDelete = nil
                }
            } message: {
                Text("Its notes won't be deleted. They'll stay in All Notes.")
            }
        }
    }

    private func startRename(_ folder: NoteFolder) {
        renameText = folder.name
        renaming = folder
    }

    private func saveRename() {
        let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let folder = renaming, !name.isEmpty {
            folder.name = String(name.prefix(40))
            try? context.save()
        }
        renaming = nil
    }

    private func createFolder() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty,
              !folders.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) else { return }
        context.insert(NoteFolder(name: String(name.prefix(40))))
        try? context.save()
    }
}

/// Folder choice used by the note editor.
struct FolderPicker: View {
    @Query(sort: \NoteFolder.name) private var folders: [NoteFolder]
    @Binding var selection: NoteFolder?

    var body: some View {
        if !folders.isEmpty {
            Picker(selection: $selection) {
                Text("None").tag(NoteFolder?.none)
                ForEach(folders) { folder in
                    Text(folder.name).tag(Optional(folder))
                }
            } label: {
                Label("Folder", systemImage: "folder")
            }
        }
    }
}
