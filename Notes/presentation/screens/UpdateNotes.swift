//
//  UpdateNotes.swift
//  Notes
//
//  Created by Muhammad Khubaib Imtiaz on 07/11/2024.
//

import SwiftUI
import SwiftData
import MapKit

struct UpdateNotes: View {
    
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @Binding var title: String
    @Binding var desc: String
    @Binding var navTitle: String
    
    @State private var isMapSheet: Bool = false
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522),
            span: MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1)
        )
    )
    
    @Binding var selectedLocation: CLLocationCoordinate2D?
    @Binding var selectedLocationName: String
    
    var onSave: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                // Title and Description Section
                Section(header: Text("Details")) {
                    TextField("Title", text: $title)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Description", text: $desc)
                        .textFieldStyle(.roundedBorder)
                }
                
                // Location Section
                Section(header: Text("Location")) {
                    if let location = selectedLocation {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Selected Location:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text(selectedLocationName)
                                .font(.body)
                                .fontWeight(.medium)
                                .lineLimit(2)
                            
                            Map(position: $position) {
                                Marker(selectedLocationName, coordinate: location)
                            }
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    } else {
                        Text("No location selected")
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: {
                        isMapSheet.toggle()
                    }) {
                        HStack {
                            Image(systemName: "map")
                            Text("Select Location")
                        }
                    }
                }
            }
            .onAppear {
                if let location = selectedLocation {
                    position = .region(
                        MKCoordinateRegion(
                            center: location,
                            span: MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1)
                        )
                    )
                    fetchLocationName(for: location) { name in
                        selectedLocationName = name ?? "No Selected Location"
                    }
                }
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        onSave()
                        dismiss()
                    }) {
                        Text("Save")
                            .fontWeight(.bold)
                    }
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $isMapSheet) {
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
                            .onTapGesture {position in
                                if let mapLocation = proxy.convert(position, from: .local) {
                                    print("Location: \(mapLocation)")
                                    selectedLocation = mapLocation
                                    
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
                    }
                    .navigationTitle("Select Location")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(.hidden, for: .navigationBar)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                dismiss()
                            }
                        }
                        
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Update Location") {
                                isMapSheet = !isMapSheet
                            }
                        }
                    }
                }
            }
        }
    }
    private func fetchLocationName(for coordinate: CLLocationCoordinate2D, completion: @escaping (String?) -> Void) {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        geocoder.reverseGeocodeLocation(location) {placemarks, error in
            if let error = error {
                completion(error.localizedDescription)
            }else{
                completion(nil)
            }
            
            if let placemark = placemarks?.first {
                let name = [placemark.name, placemark.locality, placemark.country]
                    .compactMap{$0}
                    .joined(separator: ", ")
                completion(name)
            }else {
                completion(nil)
            }
        }
    }
}
