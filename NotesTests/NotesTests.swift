//
//  NotesTests.swift
//  NotesTests
//
//  Unit tests for the app's data logic (no UI).
//

import Testing
import Foundation
import SwiftData
@testable import CloudNote_AI

// MARK: - Helpers

@MainActor
private func makeContext() throws -> ModelContext {
    let config = ModelConfiguration(schema: SharedStore.schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: SharedStore.schema, configurations: [config])
    return ModelContext(container)
}

// MARK: - Shared text helpers

@Suite struct NoteTextTests {
    @Test func firstLineBecomesTitle() {
        let (title, body) = NoteText.split("Groceries\nMilk\nEggs")
        #expect(title == "Groceries")
        #expect(body == "Milk\nEggs")
    }

    @Test func longFirstLineIsShortenedAndKeptInBody() {
        let long = String(repeating: "word ", count: 40)
        let (title, body) = NoteText.split(long)
        #expect(title.count <= NoteText.maxTitleLength)
        #expect(title.hasSuffix("…"))
        #expect(body == long.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    @Test func blankTextGivesEmptyTitle() {
        #expect(NoteText.split("   \n ").title.isEmpty)
    }
}

// MARK: - Links used by widgets, Siri and reminders

@Suite struct AppRouteTests {
    @Test(arguments: [
        AppRoute.newNote, .todos, .note(id: "ABC-123"), .todo(id: "T-9")
    ])
    func roundTripsThroughURL(route: AppRoute) {
        #expect(AppRoute(url: route.url) == route)
    }

    @Test func rejectsOtherSchemesAndBadLinks() {
        #expect(AppRoute(url: URL(string: "https://example.com/note/1")!) == nil)
        #expect(AppRoute(url: URL(string: "cloudnote://note/")!) == nil)
        #expect(AppRoute(url: URL(string: "cloudnote://unknown")!) == nil)
    }

    @Test func todoRoutesOpenTheTodoTab() {
        #expect(AppRoute.todo(id: "1").isTodoTab)
        #expect(AppRoute.todos.isTodoTab)
        #expect(!AppRoute.note(id: "1").isTodoTab)
    }
}

// MARK: - Rich text

@Suite struct RichTextTests {
    @Test func plainNotesFallBackToPlainText() {
        let text = RichTextCoder.decode(nil, fallback: "Hello", baseSize: 16)
        #expect(String(text.characters) == "Hello")
    }

    @Test func splitsIntoLinesKeepingEmptyOnes() {
        let lines = RichTextCoder.lines(of: AttributedString("one\n\nthree"))
        #expect(lines.map { String($0.characters) } == ["one", "", "three"])
    }

    @Test func trimsSurroundingWhitespace() {
        let trimmed = RichTextCoder.trimmed(AttributedString("  hi there \n"))
        #expect(String(trimmed.characters) == "hi there")
    }

    @Test func decodesSavedRuns() throws {
        let runs = [RichTextRun(text: "Bold", bold: true), RichTextRun(text: " plain")]
        let data = try JSONEncoder().encode(runs)
        let text = RichTextCoder.decode(data, fallback: "ignored", baseSize: 16)
        #expect(String(text.characters) == "Bold plain")
    }
}

// MARK: - Notes model

@Suite @MainActor struct NotesModelTests {
    @Test func checklistKeepsItsOrder() throws {
        let context = try makeContext()
        let note = NotesItem(title: "List", desc: "", isPinned: false,
                             checklist: ["C", "A", "B"].map { ChecklistItem(title: $0) })
        context.insert(note)
        try context.save()
        #expect(note.checklist.map(\.title) == ["C", "A", "B"])
    }

    @Test func colorIsStoredByName() {
        let note = NotesItem(title: "x", desc: "", isPinned: false)
        note.noteColor = .green
        #expect(note.colorName == "green")
        note.noteColor = nil
        #expect(note.colorName == nil)
    }

    @Test func templatesHaveUniqueIDsAndTitles() {
        let ids = NoteTemplate.all.map(\.id)
        #expect(Set(ids).count == ids.count)
        #expect(NoteTemplate.all.allSatisfy { !$0.title().isEmpty })
    }
}

// MARK: - Recently Deleted

@Suite @MainActor struct TrashTests {
    @Test func daysLeftCountsDown() {
        let note = NotesItem(title: "x", desc: "", isPinned: false)
        let now = Date()
        note.deletedAt = Calendar.current.date(byAdding: .day, value: -10, to: now)
        #expect(NoteTrash.daysLeft(for: note, now: now) == 20)
    }

    @Test func purgeRemovesOnlyExpiredNotes() throws {
        let context = try makeContext()
        let now = Date()
        let old = NotesItem(title: "old", desc: "", isPinned: false)
        old.deletedAt = Calendar.current.date(byAdding: .day, value: -31, to: now)
        let recent = NotesItem(title: "recent", desc: "", isPinned: false)
        recent.deletedAt = Calendar.current.date(byAdding: .day, value: -2, to: now)
        let kept = NotesItem(title: "kept", desc: "", isPinned: false)
        [old, recent, kept].forEach(context.insert)
        try context.save()

        NoteTrash.purgeExpired(context: context, now: now)

        let titles = try context.fetch(FetchDescriptor<NotesItem>()).map(\.title).sorted()
        #expect(titles == ["kept", "recent"])
    }
}

// MARK: - Backup and import

@Suite @MainActor struct BackupTests {
    @Test func exportThenImportRestoresEverything() throws {
        let source = try makeContext()
        let folder = NoteFolder(name: "Work")
        source.insert(folder)
        let note = NotesItem(title: "Plan", desc: "Body", isPinned: true, tags: ["work"],
                             checklist: ["One", "Two"].map { ChecklistItem(title: $0) })
        note.folder = folder
        note.noteColor = .blue
        source.insert(note)
        let trashed = NotesItem(title: "Gone", desc: "", isPinned: false)
        trashed.deletedAt = Date()
        source.insert(trashed)
        source.insert(TodoItem(title: "Call", isCompleted: false, priority: .high))
        try source.save()

        let data = try DataManager.exportBackup(context: source)

        let target = try makeContext()
        let added = try DataManager.importBackup(data, context: target)
        #expect(added.notes == 1)   // the note in Recently Deleted isn't backed up
        #expect(added.todos == 1)

        let restored = try #require(try target.fetch(FetchDescriptor<NotesItem>()).first)
        #expect(restored.title == "Plan")
        #expect(restored.isPinned)
        #expect(restored.tags == ["work"])
        #expect(restored.checklist.map(\.title) == ["One", "Two"])
        #expect(restored.folder?.name == "Work")
        #expect(restored.noteColor == .blue)
        #expect(try target.fetch(FetchDescriptor<TodoItem>()).first?.priority == .high)
    }

    @Test func importingTwiceDoesNotDuplicate() throws {
        let source = try makeContext()
        source.insert(NotesItem(title: "Once", desc: "", isPinned: false))
        try source.save()
        let data = try DataManager.exportBackup(context: source)

        let target = try makeContext()
        _ = try DataManager.importBackup(data, context: target)
        let second = try DataManager.importBackup(data, context: target)
        #expect(second.notes == 0)
        #expect(try target.fetchCount(FetchDescriptor<NotesItem>()) == 1)
    }

    @Test func rejectsFilesThatAreNotBackups() throws {
        let context = try makeContext()
        #expect(throws: DecodingError.self) {
            try DataManager.importBackup(Data("not json".utf8), context: context)
        }
    }
}

// MARK: - Spotlight

@Suite struct SpotlightTests {
    @MainActor @Test func noteIdentifierRoutesToNoteOpen() {
        let route = SpotlightIndex.route(for: "note:abc-123")
        #expect(route == .note(id: "abc-123"))
    }

    @MainActor @Test func todoIdentifierRoutesToTodoOpen() {
        let route = SpotlightIndex.route(for: "todo:42")
        #expect(route == .todo(id: "42"))
    }

    @MainActor @Test func unknownOrEmptyIdentifierReturnsNil() {
        #expect(SpotlightIndex.route(for: "other:1") == nil)
        #expect(SpotlightIndex.route(for: "note:") == nil)
        #expect(SpotlightIndex.route(for: "todo:") == nil)
    }
}
