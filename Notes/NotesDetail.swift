//
//  NotesDetail.swift
//  Notes
//
//  Created by Muhammad Khubaib Imtiaz on 03/11/2024.
//

import SwiftUI
import CoreLocation
import MapKit
import AVKit

struct NotesDetail: View {
    @State var notesItem: NotesItem
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
            Section {
                HStack {
                    Text(notesItem.title)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    if notesItem.isPinned {
                        Image(systemName: "pin.fill")
                            .foregroundColor(.red)
                    }
                }
            }
            
            Section(header: Text("Description")) {
                Text(notesItem.desc)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            if let imagesData = notesItem.images, !imagesData.isEmpty {
                Section(header: Text("Images")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(imagesData, id: \.self) { imageData in
                                if let uiImage = UIImage(data: imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 150, height: 150)
                                        .clipped()
                                        .cornerRadius(10)
                                        .onTapGesture {
                                            imageSheetExpanded = !imageSheetExpanded
                                        }
                                }
                            }
                        }
                    }
                    .frame(height: 160)
                }
                .sheet(isPresented: $imageSheetExpanded) {
                    ZStack(alignment: .topTrailing) {
                        VStack(spacing: 0) {
                            if let imagesData = notesItem.images, imagesData.indices.contains(selectedImageIndex) {
                                Image(uiImage: UIImage(data: imagesData[selectedImageIndex])!)
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
                .onAppear {
                    if let location = notesItem.location {
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
            }
            
            if let location = notesItem.location {
                Section(header: Text("Location")) {
                    Map(position: $position) {
                        Marker(selectedLocationName, coordinate: location)
                    }
                    .frame(height: 200)
                    .cornerRadius(10)
                }
            }
            
            if let videoURL = notesItem.videoURL {
                Section(header: Text("Video")) {
                    VideoPlayer(player: AVPlayer(url: videoURL))
                        .frame(height: 250)
                        .cornerRadius(10)
                }
            }
        }
        .navigationTitle("Note Details")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func fetchLocationName(for coordinate: CLLocationCoordinate2D, completion: @escaping (String?) -> Void) {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
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
    
    private func thumbnailScrollView(imagesData: [Data]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 10) {
                ForEach(Array(imagesData.enumerated()), id: \.element) { index, imageData in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedImageIndex = index
                        }
                    } label: {
                        Image(uiImage: UIImage(data: imageData)!)
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
            .padding(.vertical, 8)
            .padding(.horizontal, 20)
        }
        .frame(height: 80)
    }
}
