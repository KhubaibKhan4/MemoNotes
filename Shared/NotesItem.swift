//
//  NotesItem.swift
//  Notes
//
//  Created by Muhammad Khubaib Imtiaz on 19/10/2024.
//

import Foundation
import SwiftData
import CoreLocation

// iCloud (CloudKit) sync rules for these models:
// - every stored property is optional or has a default value,
// - every relationship is optional and has an inverse,
// - no unique constraints.
// Breaking any of these stops sync from starting.

@Model
class NotesItem: Identifiable {
    var id: String = UUID().uuidString
    var title: String = ""
    /// Plain text of the note body (used for search, previews, reminders and backups).
    var desc: String = ""
    /// Formatting for `desc`, as JSON-encoded `RichTextRun`s. `nil` for plain notes.
    var richText: Data? = nil
    var isPinned: Bool = false

    // Persist coordinates separately; expose as computed CLLocationCoordinate2D
    var latitude: Double?
    var longitude: Double?
    var location: CLLocationCoordinate2D? {
        get {
            if let latitude = latitude, let longitude = longitude {
                return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            }
            return nil
        }
        set {
            latitude = newValue?.latitude
            longitude = newValue?.longitude
        }
    }

    // Media
    // Images are stored outside the database file (and as CloudKit assets when syncing).
    @Attribute(.externalStorage) var images: [Data]?
    /// Local video file. Videos stay on the device that added them; they are not synced.
    var videoURL: URL?
    /// Encoded PKDrawing for a hand-drawn sketch inside this note. `nil` when empty.
    @Attribute(.externalStorage) var sketchData: Data? = nil
    /// Local audio recording. Stays on the device that added it; not synced.
    var audioURL: URL? = nil
    /// On-device transcript of `audioURL`, if the user asked for one. Synced.
    var audioTranscript: String? = nil

    var tags: [String] = []

    /// Stored checklist. Use `checklist` instead, which keeps the items in order.
    @Relationship(deleteRule: .cascade, originalName: "checklist", inverse: \ChecklistItem.note)
    var checklistItems: [ChecklistItem]? = []

    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    /// When set and in the future, a notification fires at this time.
    var reminderDate: Date? = nil
    
    /// The folder this note is filed in, if any.
    var folder: NoteFolder?
    
    /// When the note was moved to Recently Deleted. `nil` for normal notes.
    /// Notes are removed for good 30 days after this.
    var deletedAt: Date? = nil
    
    /// Card color (a `NoteColor` name). `nil` for the default look.
    var colorName: String? = nil
    
    var isInTrash: Bool { deletedAt != nil }

    /// Checklist items in display order. SwiftData relationships are unordered,
    /// so the order is kept in each item's `sortIndex`.
    var checklist: [ChecklistItem] {
        get {
            (checklistItems ?? []).sorted { $0.sortIndex < $1.sortIndex }
        }
        set {
            for (index, item) in newValue.enumerated() {
                item.sortIndex = index
            }
            checklistItems = newValue
        }
    }

    init(
        title: String,
        desc: String,
        isPinned: Bool,
        location: CLLocationCoordinate2D? = nil,
        images: [Data]? = nil,
        videoURL: URL? = nil,
        tags: [String] = [],
        checklist: [ChecklistItem] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = UUID().uuidString
        self.title = title
        self.desc = desc
        self.isPinned = isPinned
        self.latitude = location?.latitude
        self.longitude = location?.longitude
        self.images = images
        self.videoURL = videoURL
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.checklist = checklist
    }
}

@Model
class ChecklistItem: Identifiable {
    var id: String = UUID().uuidString
    var title: String = ""
    var isDone: Bool = false
    /// Position within the note's checklist.
    var sortIndex: Int = 0
    /// The note this item belongs to (inverse of `NotesItem.checklistItems`).
    var note: NotesItem?

    init(id: String = UUID().uuidString, title: String, isDone: Bool = false) {
        self.id = id
        self.title = title
        self.isDone = isDone
    }
}
