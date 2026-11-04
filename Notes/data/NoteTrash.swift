//
//  NoteTrash.swift
//  Notes
//
//  Recently Deleted: deleted notes are kept for 30 days so they can be restored.
//

import Foundation
import SwiftData

@MainActor
enum NoteTrash {

    static let keepDays = 30

    /// Moves a note to Recently Deleted and cancels its reminder.
    static func moveToTrash(_ note: NotesItem, context: ModelContext) {
        note.deletedAt = Date()
        note.isPinned = false
        ReminderScheduler.cancel(noteID: note.id)
        try? context.save()
        SharedStore.reloadWidgets()
    }

    /// Puts a note back where it was, with its reminder if that's still ahead.
    static func restore(_ note: NotesItem, context: ModelContext) {
        note.deletedAt = nil
        try? context.save()
        ReminderScheduler.schedule(note)
        SharedStore.reloadWidgets()
    }

    /// Removes a note for good, including its video file.
    static func deletePermanently(_ note: NotesItem, context: ModelContext) {
        ReminderScheduler.cancel(noteID: note.id)
        MediaStore.deleteVideo(note.videoURL)
        context.delete(note)
        try? context.save()
    }

    static func daysLeft(for note: NotesItem, now: Date = Date()) -> Int {
        guard let deletedAt = note.deletedAt else { return keepDays }
        let elapsed = Calendar.current.dateComponents([.day], from: deletedAt, to: now).day ?? 0
        return max(0, keepDays - elapsed)
    }

    /// Permanently removes notes that have been in Recently Deleted for 30 days.
    static func purgeExpired(context: ModelContext, now: Date = Date()) {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -keepDays, to: now) else { return }
        let descriptor = FetchDescriptor<NotesItem>(predicate: #Predicate { $0.deletedAt != nil })
        let trashed = (try? context.fetch(descriptor)) ?? []
        let expired = trashed.filter { ($0.deletedAt ?? now) <= cutoff }
        guard !expired.isEmpty else { return }
        for note in expired {
            MediaStore.deleteVideo(note.videoURL)
            context.delete(note)
        }
        try? context.save()
    }
}
