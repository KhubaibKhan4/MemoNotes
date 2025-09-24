//
//  NotesItem.swift
//  Notes
//
//  Created by Muhammad Khubaib Imtiaz on 19/10/2024.
//

import Foundation
import SwiftData
import CoreLocation

@Model
class NotesItem: Identifiable {
    var id: String
    var title: String
    var desc: String
    var isPinned: Bool
    
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
    // Store image data externally to avoid Core Data transformable class issues and keep the store slim.
    @Attribute(.externalStorage) var images: [Data]?
    var videoURL: URL?
    
    // New fields
    var tags: [String]
    @Relationship(deleteRule: .cascade) var checklist: [ChecklistItem]
    var createdAt: Date
    var updatedAt: Date
    
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
        self.checklist = checklist
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
class ChecklistItem: Identifiable {
    var id: String
    var title: String
    var isDone: Bool
    
    init(id: String = UUID().uuidString, title: String, isDone: Bool = false) {
        self.id = id
        self.title = title
        self.isDone = isDone
    }
}
