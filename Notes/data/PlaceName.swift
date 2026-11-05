//
//  PlaceName.swift
//  Notes
//
//  Turns a map coordinate into a readable place name, using MapKit's
//  reverse geocoding (replaces CLGeocoder, deprecated in iOS 26).
//

import MapKit

enum PlaceName {

    /// Looks up a name such as "Badshahi Mosque, Lahore, Pakistan". Calls back on the main thread.
    @MainActor
    static func lookup(_ coordinate: CLLocationCoordinate2D, completion: @escaping (String?) -> Void) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let request = MKReverseGeocodingRequest(location: location) else {
            completion(nil)
            return
        }
        Task { @MainActor in
            let item = try? await request.mapItems.first
            completion(describe(item))
        }
    }

    /// Place name plus city/country, without repeating parts.
    static func describe(_ item: MKMapItem?) -> String? {
        guard let item else { return nil }
        var parts: [String] = []
        for part in [item.name, item.addressRepresentations?.cityWithContext] {
            if let part, !part.isEmpty, !parts.contains(part) { parts.append(part) }
        }
        if parts.isEmpty, let short = item.address?.shortAddress { return short }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}
