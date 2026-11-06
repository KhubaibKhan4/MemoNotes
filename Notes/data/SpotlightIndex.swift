//
//  SpotlightIndex.swift
//  Indexes notes and todos so they show up in iPhone search (Spotlight).
//

import Foundation
import CoreSpotlight
import SwiftData
import UIKit

/// Builds Spotlight items for notes and todos and keeps the index in sync.
///
/// The index lives in the system; it survives app restarts. We still rebuild it
/// on every launch so a wipe, a restore from backup, or a new install catches up
/// with CloudKit changes that happened while the app was closed.
@MainActor
enum SpotlightIndex {

    /// One domain per record kind so we can wipe each independently.
    static let notesDomain = "com.brikmas.aipowerednotes.sync.notes.notes"
    static let todosDomain = "com.brikmas.aipowerednotes.sync.notes.todos"

    // MARK: - Public API

    /// Reads every note and todo from `context` and sends them to Spotlight.
    /// Call once at launch and after a big change such as an import.
    static func reindexEverything(from context: ModelContext) {
        guard CSSearchableIndex.isIndexingAvailable() else { return }
        // A locked app hides note content from the UI, so hide it from search too.
        guard !SharedStore.isAppLockEnabled else {
            deleteEverything()
            return
        }
        let notes = (try? context.fetch(FetchDescriptor<NotesItem>())) ?? []
        let todos = (try? context.fetch(FetchDescriptor<TodoItem>())) ?? []
        let items = notes.map(searchableItem(for:)) + todos.map(searchableItem(for:))
        CSSearchableIndex.default().indexSearchableItems(items) { error in
            if let error { print("Spotlight: couldn't reindex: \(error)") }
        }
    }

    /// Adds or replaces one note. Fine to call after every save.
    static func upsert(_ note: NotesItem) {
        guard CSSearchableIndex.isIndexingAvailable(), !SharedStore.isAppLockEnabled else { return }
        CSSearchableIndex.default().indexSearchableItems([searchableItem(for: note)]) { error in
            if let error { print("Spotlight: couldn't index note: \(error)") }
        }
    }

    /// Adds or replaces one todo.
    static func upsert(_ todo: TodoItem) {
        guard CSSearchableIndex.isIndexingAvailable(), !SharedStore.isAppLockEnabled else { return }
        CSSearchableIndex.default().indexSearchableItems([searchableItem(for: todo)]) { error in
            if let error { print("Spotlight: couldn't index todo: \(error)") }
        }
    }

    /// Removes one note from Spotlight (call before deleting it from the database).
    static func removeNote(id: String) {
        guard CSSearchableIndex.isIndexingAvailable() else { return }
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [noteIdentifier(id)]) { _ in }
    }

    /// Removes one todo from Spotlight.
    static func removeTodo(id: String) {
        guard CSSearchableIndex.isIndexingAvailable() else { return }
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [todoIdentifier(id)]) { _ in }
    }

    /// Wipes every indexed item. Used when App Lock is turned on or when the user resets.
    static func deleteEverything() {
        guard CSSearchableIndex.isIndexingAvailable() else { return }
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [notesDomain, todosDomain]) { _ in }
    }

    // MARK: - Identifiers

    /// Reads the note id from a Spotlight identifier and returns an `AppRoute`.
    /// Used by `continueUserActivity` to open the right screen from a search hit.
    static func route(for spotlightIdentifier: String) -> AppRoute? {
        if spotlightIdentifier.hasPrefix("note:") {
            let id = String(spotlightIdentifier.dropFirst("note:".count))
            return id.isEmpty ? nil : .note(id: id)
        }
        if spotlightIdentifier.hasPrefix("todo:") {
            let id = String(spotlightIdentifier.dropFirst("todo:".count))
            return id.isEmpty ? nil : .todo(id: id)
        }
        return nil
    }

    private static func noteIdentifier(_ id: String) -> String { "note:\(id)" }
    private static func todoIdentifier(_ id: String) -> String { "todo:\(id)" }

    // MARK: - Item builders

    private static func searchableItem(for note: NotesItem) -> CSSearchableItem {
        // kUTTypePlainText is the common catch-all content type for arbitrary text.
        let attrs = CSSearchableItemAttributeSet(contentType: .text)
        attrs.title = note.title.isEmpty ? String(localized: "Note") : note.title
        attrs.contentDescription = String(note.desc.prefix(400))
        attrs.keywords = note.tags
        attrs.contentCreationDate = note.createdAt
        attrs.contentModificationDate = note.updatedAt
        if let data = note.images?.first, let image = UIImage(data: data) {
            attrs.thumbnailData = image.jpegData(compressionQuality: 0.6)
        }
        let item = CSSearchableItem(
            uniqueIdentifier: noteIdentifier(note.id),
            domainIdentifier: notesDomain,
            attributeSet: attrs
        )
        // Pinned notes rank slightly higher.
        item.expirationDate = .distantFuture
        return item
    }

    private static func searchableItem(for todo: TodoItem) -> CSSearchableItem {
        let attrs = CSSearchableItemAttributeSet(contentType: .text)
        attrs.title = todo.title.isEmpty ? String(localized: "Task") : todo.title
        attrs.contentDescription = todo.notes.isEmpty
            ? (todo.dueDate.map { formattedDueDate($0) } ?? "")
            : todo.notes
        attrs.contentCreationDate = todo.createdAt
        if let due = todo.dueDate { attrs.dueDate = due }
        let item = CSSearchableItem(
            uniqueIdentifier: todoIdentifier(todo.id),
            domainIdentifier: todosDomain,
            attributeSet: attrs
        )
        item.expirationDate = .distantFuture
        return item
    }

    private static func formattedDueDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}
