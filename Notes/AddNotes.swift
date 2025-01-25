//
//  AddNotes.swift
//  Notes
//
//  Created by Muhammad Khubaib Imtiaz on 19/10/2024.
//

import SwiftUI
import SwiftData
import MapKit

struct AddNotes: View {
    
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @Binding var title: String
    @Binding var desc: String
    @Binding var navTitle: String
    
    @State private var isMapSheet: Bool = false
    @State private var locationList = [CLLocationCoordinate2D]()
    
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522), span: MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1)))
    
    @Environment(\.presentationMode) private var presentationMode: Binding<PresentationMode>
    @State var selectedLocation : CLLocationCoordinate2D?
    @State private var selectedLocationName: String = "No Location Selected"
    
    @StateObject private var locationManager = LocationManager()
    
    var onSave: () -> Void
    
    var body: some View {
        VStack{
            Form {
                Section("Note") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $desc)
                }
                Section("Map") {
                    Button("Add Map", systemImage: "map.circle") {
                        isMapSheet = !isMapSheet
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
                
                Section("Media") {
                    Button("Add Media", systemImage: "photo.on.rectangle.angled.fill") {
                        locationManager.checkLocationAuthorization()
                    }
                    .foregroundColor(.white)
                    .buttonStyle(.borderedProminent)
                }
                
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
                                /// Shows up when you pitch to zoom
                                MapScaleView()
                                /// Shows up when you rotate the map
                                MapCompass()
                                /// 3D and 2D button on the top right
                                MapPitchToggle()
                            })
                            .frame(width: .infinity, height: .infinity)
                            .onTapGesture {position in
                                if let mapLocation = proxy.convert(position, from: .local) {
                                    print("Location: \(mapLocation)")
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
                        var item = NotesItem(title: title, desc: desc, isPinned: false, location: selectedLocation)
                        context.insert(item)
                        try? context.save()
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
}
