//
//  NoteAIViews.swift
//  Notes
//
//  Screens for the on-device AI features in note details.
//

import SwiftUI
import SwiftData
import UIKit

/// The AI actions offered on a note.
enum NoteAIAction: String, Identifiable {
    case summarize
    case actionItems

    var id: String { rawValue }
}

/// Sparkles menu for the note details toolbar. Hidden on devices without Apple Intelligence.
struct NoteAIMenu: View {
    @Binding var activeAction: NoteAIAction?
    @State private var unavailableMessage: String?

    var body: some View {
        if NoteAI.isSupported {
            Menu {
                Button {
                    open(.summarize)
                } label: {
                    Label("Summarize", systemImage: "text.alignleft")
                }
                Button {
                    open(.actionItems)
                } label: {
                    Label("Find Action Items", systemImage: "checklist")
                }
            } label: {
                Image(systemName: "sparkles")
            }
            .accessibilityLabel("AI")
            .alert(
                "Apple Intelligence",
                isPresented: Binding(get: { unavailableMessage != nil }, set: { if !$0 { unavailableMessage = nil } })
            ) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(unavailableMessage ?? "")
            }
        }
    }

    private func open(_ action: NoteAIAction) {
        if case .unavailable(let message) = NoteAI.status {
            unavailableMessage = message
        } else {
            activeAction = action
        }
    }
}

// MARK: - Summary

struct NoteSummarySheet: View {
    let note: NotesItem
    @Environment(\.dismiss) private var dismiss

    @State private var summary: NoteSummary?
    @State private var errorMessage: String?
    @State private var copied = false

    var body: some View {
        NavigationStack {
            Group {
                if let summary {
                    List {
                        Section("Summary") {
                            Text(summary.summary)
                                .textSelection(.enabled)
                        }
                        if !summary.keyPoints.isEmpty {
                            Section("Key Points") {
                                ForEach(summary.keyPoints, id: \.self) { point in
                                    Label(point, systemImage: "circle.fill")
                                        .labelStyle(BulletLabelStyle())
                                }
                            }
                        }
                        Section {
                            Button {
                                UIPasteboard.general.string = copyText(summary)
                                copied = true
                                Haptics.success()
                            } label: {
                                Label(copied ? "Copied" : "Copy Summary", systemImage: copied ? "checkmark" : "doc.on.doc")
                            }
                        } footer: {
                            Text("Created on this iPhone with Apple Intelligence. Check it before relying on it.")
                        }
                    }
                } else if let errorMessage {
                    ContentUnavailableView("Couldn't Summarize", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                } else {
                    ProgressView("Summarizing…")
                }
            }
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        do {
            summary = try await NoteAI.summarize(title: note.title, body: note.desc)
        } catch {
            errorMessage = NoteAI.message(for: error)
        }
    }

    private func copyText(_ summary: NoteSummary) -> String {
        ([summary.summary] + summary.keyPoints.map { "• \($0)" }).joined(separator: "\n")
    }
}

// MARK: - Action items

struct NoteActionItemsSheet: View {
    let note: NotesItem
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var items: [String]?
    @State private var selected: Set<String> = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if let items, items.isEmpty {
                    ContentUnavailableView("No Action Items", systemImage: "checklist", description: Text("Apple Intelligence didn't find anything to do in this note."))
                } else if let items {
                    List {
                        Section {
                            ForEach(items, id: \.self) { item in
                                Button {
                                    toggle(item)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: selected.contains(item) ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(selected.contains(item) ? Color.accentColor : .secondary)
                                        Text(item).foregroundStyle(.primary)
                                    }
                                }
                            }
                        } header: {
                            Text("Choose items to add")
                        } footer: {
                            Text("Found on this iPhone with Apple Intelligence.")
                        }

                        Section {
                            Button {
                                addToChecklist()
                            } label: {
                                Label("Add to Note Checklist", systemImage: "checklist")
                            }
                            Button {
                                addAsTasks()
                            } label: {
                                Label("Add to Todo List", systemImage: "plus.circle")
                            }
                        }
                        .disabled(selected.isEmpty)
                    }
                } else if let errorMessage {
                    ContentUnavailableView("Couldn't Find Action Items", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                } else {
                    ProgressView("Reading your note…")
                }
            }
            .navigationTitle("Action Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        do {
            let found = try await NoteAI.actionItems(title: note.title, body: note.desc)
            // Skip items the note's checklist already has.
            let existing = Set(note.checklist.map { $0.title.lowercased() })
            var seen = Set<String>()
            let fresh = found.filter { !existing.contains($0.lowercased()) && seen.insert($0.lowercased()).inserted }
            items = fresh
            selected = Set(fresh)
        } catch {
            errorMessage = NoteAI.message(for: error)
        }
    }

    private func toggle(_ item: String) {
        if selected.contains(item) {
            selected.remove(item)
        } else {
            selected.insert(item)
        }
    }

    /// Selected items, in the order they were found.
    private var chosen: [String] {
        (items ?? []).filter { selected.contains($0) }
    }

    private func addToChecklist() {
        note.checklist = note.checklist + chosen.map { ChecklistItem(title: $0) }
        note.updatedAt = Date()
        try? context.save()
        Haptics.success()
        dismiss()
    }

    private func addAsTasks() {
        for item in chosen {
            context.insert(TodoItem(title: item, isCompleted: false, notes: String(localized: "From note: \(note.title)")))
        }
        try? context.save()
        SharedStore.reloadWidgets()
        Haptics.success()
        dismiss()
    }
}

/// A small dot before the text, for key points.
private struct BulletLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            configuration.icon
                .font(.system(size: 6))
                .foregroundStyle(.secondary)
            configuration.title
        }
    }
}
