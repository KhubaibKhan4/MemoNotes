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
    
    var images: [Data]?
    var videoURL: URL?
    
    init(title: String, desc: String, isPinned: Bool, location: CLLocationCoordinate2D? = nil, images: [Data]? = nil, videoURL: URL? = nil) {
        self.id = UUID().uuidString
        self.title = title
        self.desc = desc
        self.isPinned = isPinned
        self.latitude = location?.latitude
        self.longitude = location?.longitude
        self.images = images
        self.videoURL = videoURL
    }
}
