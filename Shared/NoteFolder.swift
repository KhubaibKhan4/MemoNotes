//
//  NoteFolder.swift
//  Shared by the app, the Share Extension and the widgets.
//

import Foundation
import SwiftData

/// A folder notes can be filed in (for example "Work" or "WhatsApp").
/// Follows the iCloud rules described in NotesItem.swift.
@Model
class NoteFolder: Identifiable {
    var id: String = UUID().uuidString
    var name: String = ""
    var createdAt: Date = Date()

    /// Deleting a folder keeps its notes; they just stop being in a folder.
    @Relationship(deleteRule: .nullify, inverse: \NotesItem.folder)
    var notes: [NotesItem]? = []

    init(name: String) {
        self.id = UUID().uuidString
        self.name = name
        self.createdAt = Date()
    }

    /// Notes in this folder that aren't in Recently Deleted.
    var activeNoteCount: Int {
        (notes ?? []).filter { $0.deletedAt == nil }.count
    }
}
