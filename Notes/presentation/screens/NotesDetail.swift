//
//  NotesDetail.swift
//  Notes
//
//  Created by Muhammad Khubaib Imtiaz on 03/11/2024.
//

import SwiftUI
import SwiftData
import CoreLocation
import MapKit
import AVKit

struct NotesDetail: View {
    @Environment(\.modelContext) private var context

    @Bindable var notesItem: NotesItem
    @State private var imageSheetExpanded: Bool = false
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522),
            span: MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1)
        )
    )
    
    @State var selectedLocationName: String = ""
    @State var isMapClicked: Bool = false
    @Environment(\.dismiss) private var dismiss
    @State private var selectedImageIndex: Int = 0
    
    var body: some View {
        List {
            // Header
            Section {
                HStack(alignment: .firstTextBaseline) {
                    Text(notesItem.title)
                        .font(.title)
                        .fontWeight(.bold)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    if notesItem.isPinned {
                        Image(systemName: "pin.fill")
                            .foregroundColor(.orange)
                    }
                }
                if !notesItem.tags.isEmpty {
                    TagsChipsView(tags: notesItem.tags, limit: 8)
                        .padding(.top, 4)
                }
                
                // Checklist summary
                if !notesItem.checklist.isEmpty {
                    let total = notesItem.checklist.count
                    let done = notesItem.checklist.filter { $0.isDone }.count
                    HStack(spacing: 8) {
                        Image(systemName: done == total ? "checkmark.circle.fill" : "checkmark.circle")
                            .foregroundColor(done == total ? .green : .gray)
                        Text("\(done)/\(total) completed")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 2)
                }
            }
            
            // Description
            Section(header: Text("Description")) {
                Text(notesItem.desc)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            // Checklist details (interactive)
            if !notesItem.checklist.isEmpty {
                Section(header: Text("Checklist")) {
                    ForEach($notesItem.checklist) { $item in
                        Toggle(isOn: $item.isDone) {
                            Text(item.title)
                        }
                        .onChange(of: item.isDone) { _, _ in
                            notesItem.updatedAt = Date()
                            try? context.save()
                        }
                    }
                    .onDelete { offsets in
                        notesItem.checklist.remove(atOffsets: offsets)
                        notesItem.updatedAt = Date()
                        try? context.save()
                    }
                }
            }
            
            // Images
            if let imagesData = notesItem.images, !imagesData.isEmpty {
                Section(header: Text("Images")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(Array(imagesData.enumerated()), id: \.offset) { idx, imageData in
                                if let uiImage = UIImage(data: imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 150, height: 150)
                                        .clipped()
                                        .cornerRadius(10)
                                        .onTapGesture {
                                            selectedImageIndex = idx
                                            imageSheetExpanded = true
                                        }
                                }
                            }
                        }
                    }
                    .frame(height: 160)
                }
            }
            
            // Map
            if let location = notesItem.location {
                Section(header: Text("Location")) {
                    Map(position: $position) {
                        Marker(selectedLocationName, coordinate: location)
                    }
                    .frame(height: 200)
                    .cornerRadius(10)
                    .onTapGesture {
                        isMapClicked = true
                    }
                }
                .onAppear {
                    position = .region(
                        MKCoordinateRegion(
                            center: location,
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        )
                    )
                    fetchLocationName(for: location) { name in
                        selectedLocationName = name ?? "Unknown"
                    }
                }
            }
            
            // Video
            if let videoURL = notesItem.videoURL {
                Section(header: Text("Video")) {
                    VideoPlayer(player: AVPlayer(url: videoURL))
                        .frame(height: 250)
                        .cornerRadius(10)
                }
            }
            
            // Dates
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .foregroundColor(.secondary)
                        Text("Created: \(formattedDate(notesItem.createdAt))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .foregroundColor(.secondary)
                        Text("Updated: \(formattedDate(notesItem.updatedAt))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .sheet(isPresented: $imageSheetExpanded) {
            if let imagesData = notesItem.images, !imagesData.isEmpty {
                ZStack(alignment: .topTrailing) {
                    VStack(spacing: 0) {
                        if imagesData.indices.contains(selectedImageIndex),
                           let ui = UIImage(data: imagesData[selectedImageIndex]) {
                            Image(uiImage: ui)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .transition(.opacity)
                                .id(selectedImageIndex)
                        }
                        
                        thumbnailScrollView(imagesData: imagesData)
                            .background(.ultraThinMaterial)
                    }
                    
                    Button {
                        imageSheetExpanded = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    .padding()
                }
                .background(.black)
                .toolbar(content: {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            imageSheetExpanded = false
                        } label: {
                            Image(systemName: "xmark")
                        }
                    }
                })
                .frame(width: .infinity, height: .infinity)
                .ignoresSafeArea(.keyboard)
            }
        }
        .sheet(isPresented: $isMapClicked) {
            FullScreenMapView(location: notesItem.location ?? CLLocationCoordinate2D(latitude: 0, longitude: 0), locationName: selectedLocationName)
        }
        .navigationTitle("Note Details")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func fetchLocationName(for coordinate: CLLocationCoordinate2D, completion: @escaping (String?) -> Void) {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        geocoder.reverseGeocodeLocation(location) { placemarks, _ in
            if let placemark = placemarks?.first {
                let name = [placemark.name, placemark.locality, placemark.country]
                    .compactMap { $0 }
                    .joined(separator: ", ")
                completion(name)
            } else {
                completion(nil)
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func thumbnailScrollView(imagesData: [Data]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 10) {
                ForEach(Array(imagesData.enumerated()), id: \.offset) { index, imageData in
                    if let ui = UIImage(data: imageData) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedImageIndex = index
                            }
                        } label: {
                            Image(uiImage: ui)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(index == selectedImageIndex ? Color.white : Color.clear, lineWidth: 2)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 20)
        }
        .frame(height: 80)
    }
}

struct FullScreenMapView: View {
    let location: CLLocationCoordinate2D
    let locationName: String
    @State private var position: MapCameraPosition
    @Environment(\.dismiss) var dismiss
    
    init(location: CLLocationCoordinate2D, locationName: String) {
        self.location = location
        self.locationName = locationName
        _position = State(initialValue: .region(MKCoordinateRegion(
            center: location,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )))
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Map(position: $position) {
                Marker(locationName, coordinate: location)
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls {
                MapCompass()
                MapPitchToggle()
                MapUserLocationButton()
            }
            .edgesIgnoringSafeArea(.all)
            
            VStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                }
                .padding()
                
                Spacer()
                
                HStack {
                    Spacer()
                    Button {
                        openMapsForDirections()
                    } label: {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding()
                            .background(Circle().fill(Color.blue.opacity(0.8)))
                    }
                    .padding()
                }
            }
        }
    }
    
    private func openMapsForDirections() {
        let placemark = MKPlacemark(coordinate: location)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = locationName
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}

// Reuse the chips view from Home
private struct TagsChipsView: View {
    let tags: [String]
    let limit: Int
    
    init(tags: [String], limit: Int = 8) {
        self.tags = tags
        self.limit = limit
    }
    
    var body: some View {
        let shown = Array(tags.prefix(limit))
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(shown, id: \.self) { tag in
                    Text(tag)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.blue.opacity(0.15)))
                        .foregroundColor(.blue)
                }
                if tags.count > shown.count {
                    Text("+\(tags.count - shown.count)")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.secondary.opacity(0.15)))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
