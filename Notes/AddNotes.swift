//
//  AddNotes.swift
//  Notes
//
//  Created by Muhammad Khubaib Imtiaz on 19/10/2024.
//

import SwiftUI
import SwiftData
import MapKit
import PhotosUI
import CoreLocation

struct AddNotes: View {
    
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedItems = [PhotosPickerItem]()
    @State private var selectedImages = [Image]()
    @State private var selectedImagesData = [Data]()
    @State private var selectedVideo: URL?
    
    @Binding var title: String
    @Binding var desc: String
    @Binding var navTitle: String
    
    @State private var isMapSheet: Bool = false
    @State private var locationList = [CLLocationCoordinate2D]()
    
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522), span: MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1)))
    
    @Environment(\.presentationMode) private var presentationMode: Binding<PresentationMode>
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var selectedLocationName: String = "No Location Selected"
    
    @StateObject private var locationManager = LocationManager()
    @State private var permissionDenied = false
    
    var onSave: () -> Void
    
    var body: some View {
        VStack {
            Form {
                Section("Note") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $desc)
                }
                Section("Map") {
                    Button("Add Map", systemImage: "map.circle") {
                        if locationManager.permissionGranted {
                            isMapSheet = true
                            if let userLocation = locationManager.userLocation {
                                zoomToUserLocation(userLocation)
                            }
                        } else {
                            locationManager.requestLocationPermission()
                        }
                    }
                    .foregroundColor(.white)
                    .buttonStyle(.borderedProminent)
                    
                    Map(position: $position) {
                        if let location = selectedLocation {
                            Marker(selectedLocationName, coordinate: location)
                        }
                    }
                    .frame(height: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        selectedLocation == nil ?
                        Text("No location selected")
                            .foregroundColor(.gray)
                            .padding()
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(10)
                        : nil
                    )
                }
                
                Section("Photos") {
                    PhotosPicker(
                        selection: $selectedItems,
                        matching: .images
                    ) {
                        Label("Select Images", systemImage: "photo.on.rectangle.angled.fill")
                            .padding(8)
                            .foregroundColor(.white)
                            .background(.blue)
                            .cornerRadius(8)

                    }
                    .foregroundColor(.white)
                    .buttonStyle(.borderedProminent)
                }
                
                if !selectedImagesData.isEmpty {
                    withAnimation {
                        Section("Selected Content") {
                            if selectedImages.isEmpty {
                                Text("No images selected")
                                    .foregroundColor(.gray)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack {
                                        ForEach(selectedImages.indices, id: \..self) { index in
                                            selectedImages[index]
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 100, height: 100)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                                .padding(4)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .onChange(of: selectedItems) { newItems in
                Task {
                    selectedImages.removeAll()

                    for item in selectedItems {
                        if let image = try? await item.loadTransferable(type: Image.self) {
                            selectedImages.append(image)
                        }
                    }
                    
                    var imageDataArray = [Data]()
                    for item in newItems {
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            imageDataArray.append(data)
                        }
                    }
                    selectedImagesData = imageDataArray
                    
                }
            }
            .onAppear {
                locationManager.checkPermissionStatus()
            }
            .onChange(of: locationManager.userLocation) { location in
                if let userLocation = location {
                    zoomToUserLocation(userLocation)
                }
            }
            .onChange(of: locationManager.permissionDenied) { denied in
                permissionDenied = denied
            }
        }.navigationTitle("Add Notes")
            .navigationBarBackButtonHidden(true)
            .sheet(isPresented: $isMapSheet, content: {
                NavigationStack {
                    ZStack {
                        MapReader { proxy in
                            Map(position: $position) {
                                Marker(coordinate: selectedLocation ?? CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522)) {
                                    Label(selectedLocationName, image: "mappin")
                                }
                            }.mapControls({
                                MapScaleView()
                                MapCompass()
                                MapPitchToggle()
                            })
                            .frame(width: .infinity, height: .infinity)
                            .onTapGesture { position in
                                if let mapLocation = proxy.convert(position, from: .local) {
                                    selectedLocation = mapLocation
                                    locationList.append(mapLocation)
                                    
                                    self.position = .region(
                                        MKCoordinateRegion(
                                            center: mapLocation,
                                            span: MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1)
                                        )
                                    )
                                    fetchLocationName(for: mapLocation) { name in
                                        self.selectedLocationName = name ?? "Unknown"
                                    }
                                }
                            }
                        }
                    }.navigationTitle("Add Map")
                        .toolbarTitleDisplayMode(.inline)
                        .toolbarBackground(.hidden, for: ToolbarPlacement.navigationBar)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Add Location") {
                                    isMapSheet = !isMapSheet
                                }
                            }
                        }
                }
            })
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "chevron.backward")
                            Text("Cancel")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let noteItem = NotesItem(
                            title: title,
                            desc: desc,
                            isPinned: false,
                            location: selectedLocation,
                            images: selectedImagesData,
                            videoURL: selectedVideo
                        )
                        
                        context.insert(noteItem)
                        onSave()
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Text("Save")
                    }
                }
            }
    }
    
    private func fetchLocationName(for coordinate: CLLocationCoordinate2D, completion: @escaping (String?) -> Void) {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                print("Reverse geocoding error: \(error.localizedDescription)")
                completion(nil)
                return
            }
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
    
    private func zoomToUserLocation(_ userLocation: CLLocation) {
        let coordinate = userLocation.coordinate
        self.position = .region(
            MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        )
    }
}

extension Image {
    func asData() -> Data? {
        guard let uiImage = self.asUIImage() else { return nil }
        return uiImage.jpegData(compressionQuality: 1.0)
    }
    
    func asUIImage() -> UIImage? {
        let hostingController = UIHostingController(rootView: self)
        let view = hostingController.view
        let size = hostingController.sizeThatFits(in: CGSize(width: 1000, height: 1000))
        view?.bounds = CGRect(origin: .zero, size: size)
        view?.setNeedsLayout()
        view?.layoutIfNeeded()
        
        UIGraphicsBeginImageContextWithOptions(view?.bounds.size ?? .zero, false, 0)
        view?.drawHierarchy(in: view?.bounds ?? .zero, afterScreenUpdates: true)
        let uiImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return uiImage
    }
}
