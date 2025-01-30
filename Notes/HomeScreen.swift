//
//  HomeScreen.swift
//  Notes
//
//  Created by Muhammad Khubaib Imtiaz on 19/10/2024.
//

import SwiftUI
import SwiftData
import CoreLocation
import MapKit

struct HomeScreen: View{
    
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    
    @Query private var notestList : [NotesItem]
    
    @State private var selectedItem: NotesItem?
    @State private var isSheetExpanded: Bool = false
    
    @State var notesTitle: String = ""
    @State var notesDesc: String = ""
    @State var navTitle: String = "Add Notes"
    
    @State var selectedLocation: CLLocationCoordinate2D?
    @State var selectedLocationName: String = "No Location Selected"
    @State var position : MapCameraPosition = .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 23.23213, longitude: 98.23123), latitudinalMeters: 1, longitudinalMeters: 1))
    
    @State var showMenu: Bool = false
    @State var searchText: String = ""
    @AppStorage("isDarkMode") private var isDark : Bool = false
    var searchResults: [NotesItem] {
        if searchText.isEmpty {
            return notestList
        } else {
            return notestList.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
    }
    @State var isSearchPresented: Bool = false
    
    var body : some View {
        NavigationView {
            VStack{
                if searchResults.isEmpty {
                    ContentUnavailableView.init("No Notes Found", systemImage: "text.page.badge.magnifyingglass", description: Text("No Notes Found in the Database. Please try to research other items."))
                    
                }else{
                    List{
                        if(searchResults.isEmpty){
                            
                        }else {
                            if(!searchResults.filter{$0.isPinned}.isEmpty){
                                Section("Pinned") {
                                    ForEach(searchResults.filter { $0.isPinned } ) { item in
                                        pinnedNotesView(for: item)
                                            .swipeActions(edge: .leading) {
                                                Button {
                                                    togglePin(for: item)
                                                } label: {
                                                    Label(item.isPinned ? "Unpin" : "Pin", systemImage: item.isPinned ? "pin.slash.fill" : "pin.fill")
                                                }
                                                .tint(.yellow)
                                            }
                                    }.onDelete { indexSet in
                                        deleteItem(at: indexSet)
                                    }
                                }
                            }
                            
                        }
                        ForEach(searchResults.filter {!$0.isPinned}) { item in
                            notesView(for: item)
                                .swipeActions(edge: .leading) {
                                    Button {
                                        togglePin(for: item)
                                    } label: {
                                        Label(item.isPinned ? "Unpin" : "Pin", systemImage: item.isPinned ? "pin.slash.fill" : "pin.fill")
                                    }
                                    .tint(.yellow)
                                }
                        }.onDelete { indexSet in
                            deleteItem(at: indexSet)
                        }
                    }.refreshable {
                        print("Refresh Notes")
                    }.toolbar {
                        ToolbarItem(placement:.topBarTrailing) {
                            EditButton()
                        }
                    }
                }
            }
            .preferredColorScheme(isDark ? .dark : .light)
            .navigationTitle("Notes")
            .searchable(text: $searchText, isPresented: $isSearchPresented)
            .toolbar {
                ToolbarItem(placement:.topBarTrailing) {
                    NavigationLink {
                        AddNotes(
                            title: $notesTitle,
                            desc: $notesDesc,
                            navTitle: $navTitle,
                            onSave: {
                                selectedItem = nil
                                notesTitle = ""
                                notesDesc = ""
                                navTitle = "Add Note"
                                let newItem = NotesItem(title: notesTitle, desc: notesDesc, isPinned: false, location: selectedLocation)
                                try? context.save()
                                isSheetExpanded = false
                            }
                        )
                    } label: {
                        Label("Add Notes", systemImage: "plus")
                            .foregroundColor(.blue)
                    }
                    
                }
            }.sheet(isPresented: $isSheetExpanded,onDismiss: {
                selectedItem = nil
                navTitle = "Add Note"
                notesTitle = ""
                notesDesc  = ""
                isSheetExpanded = false
            }) {
                UpdateNotes(
                    title: $notesTitle,
                    desc: $notesDesc,
                    navTitle: $navTitle,
                    selectedLocation: $selectedLocation,
                    selectedLocationName: $selectedLocationName,
                    onSave: {
                        if let selectedItem = selectedItem {
                            selectedItem.title = notesTitle
                            selectedItem.desc = notesDesc
                            selectedItem.location = selectedLocation
                        } else {
                            let newItem = NotesItem(title: notesTitle, desc: notesDesc, isPinned: false,location: selectedLocation)
                            context.insert(newItem)
                        }
                        try? context.save()
                        isSheetExpanded = false
                        selectedItem = nil
                        notesTitle = ""
                        notesDesc = ""
                        navTitle = "Add Note"
                    }
                )
            }
        }
        
    }
    
    
    private func deleteItem(at offset: IndexSet) {
        let itemToDelete = notestList
        for index in offset {
            let item = itemToDelete[index]
            try? context.delete(item)
        }
        do {
            try context.save()
        }catch {
            print("Error While Deleting...")
        }
    }
    func pinnedNotesView(for item: NotesItem) -> some View {
        NavigationLink(destination: NotesDetail(notesItem: item)) {
            VStack(alignment: .leading, spacing: 12) {
                
                Text(item.title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
                Text(item.desc)
                    .font(.body)
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.9) : .black.opacity(0.9))
                    .lineLimit(2)
                    .truncationMode(.tail)
                
                if let _ = item.location {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                        Text("Location Added")
                            .font(.footnote)
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
                    }
                }
                
                if let images = item.images, !images.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(images.prefix(3), id: \.self) { imageData in
                                if let uiImage = UIImage(data: imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                            if images.count > 3 {
                                Text("+\(images.count - 3)")
                                    .font(.footnote)
                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                                    .padding(6)
                                    .background(colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
                
                if let _ = item.videoURL {
                    HStack {
                        Image(systemName: "video.fill")
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                        Text("Video Attached")
                            .font(.footnote)
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
                    }
                }
            }
            .padding(16)
            .background(item.isPinned ? Color.orange : (colorScheme == .dark ? Color.black.opacity(0.8) : Color.white.opacity(0.8)))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
        }
    }
    
    
    
    func notesView(for item: NotesItem) -> some View {
        NavigationLink(destination: NotesDetail(notesItem: item)) {
            VStack(alignment: .leading, spacing: 12) {
                
                Text(item.title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
                Text(item.desc)
                    .font(.body)
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.9) : .black.opacity(0.9))
                    .lineLimit(2)
                    .truncationMode(.tail)
                
                if let _ = item.location {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                        Text("Location Added")
                            .font(.footnote)
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
                    }
                }
                
                if let images = item.images, !images.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(images.prefix(3), id: \.self) { imageData in
                                if let uiImage = UIImage(data: imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                            if images.count > 3 {
                                Text("+\(images.count - 3)")
                                    .font(.footnote)
                                    .padding(6)
                                    .background(colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
                
                if let _ = item.videoURL {
                    HStack {
                        Image(systemName: "video.fill")
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                        Text("Video Attached")
                            .font(.footnote)
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
                    }
                }
            }
            .padding(16)
            .background(item.isPinned ? Color.orange : (colorScheme == .dark ? Color.black.opacity(0.8) : Color.white.opacity(0.8)))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
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
    private func togglePin(for note: NotesItem) {
        if let index = notestList.firstIndex(where: { $0.id == note.id }) {
            notestList[index].isPinned.toggle()
            try? context.save()
        }
    }
    
    // Image View for Notes
    @ViewBuilder
    func noteImageView(for item: NotesItem) -> some View {
        if let images = item.images, !images.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(images, id: \.self) { imageData in
                        if let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .cornerRadius(12)
                                .shadow(radius: 3)
                        } else {
                            placeholderImage()
                        }
                    }
                }
            }
            .frame(height: 70)
        } else {
            placeholderImage()
        }
    }
    
    // Placeholder Image
    @ViewBuilder
    func placeholderImage() -> some View {
        Image(systemName: "photo.fill")
            .resizable()
            .scaledToFill()
            .frame(width: 60, height: 60)
            .cornerRadius(12)
            .shadow(radius: 3)
    }
    
    // Location View
    @ViewBuilder
    func locationView(for location: CLLocationCoordinate2D) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "location.fill")
                .foregroundColor(.blue)
                .font(.footnote)
            Text(String(format: "Lat: %.4f, Lon: %.4f", location.latitude, location.longitude))
                .font(.footnote)
                .foregroundColor(.gray)
        }
    }
    
    @ViewBuilder
    func editButtonPin(for item: NotesItem) -> some View {
        Button("Edit", systemImage: "pin") {
            selectedItem = item
            notesTitle = item.title
            notesDesc = item.desc
            selectedLocation = item.location
            try? context.save()
        }.tint(.white)
    }
    // Edit Button
    @ViewBuilder
    func editButton(for item: NotesItem) -> some View {
        Button("Edit", systemImage: "pencil") {
            selectedItem = item
            notesTitle = item.title
            notesDesc = item.desc
            selectedLocation = item.location
            try? context.save()
        }.tint(.blue)
    }
    
    // Delete Button
    @ViewBuilder
    func deleteButton(for item: NotesItem) -> some View {
        Button("Delete", systemImage: "trash", role: .destructive) {
            if let index = notestList.firstIndex(where: { $0.id == item.id }) {
                context.delete(notestList[index])
                try? context.save()
            }
        }
    }
    
}

#Preview {
    HomeScreen()
        .modelContainer(for: NotesItem.self, inMemory: true)
}
