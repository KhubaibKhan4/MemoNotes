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
import AVKit
import UniformTypeIdentifiers

struct AddNotes: View {
    
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    // Media selection
    @State private var selectedItems = [PhotosPickerItem]()
    @State private var selectedImages = [Image]()
    @State private var selectedImagesData = [Data]()
    @State private var selectedVideo: URL?
    @State private var selectedVideoItem: PhotosPickerItem?
    
    // Inputs
    @Binding var title: String
    @Binding var desc: String
    @Binding var navTitle: String
    
    @State private var isPinned: Bool = false
    
    // Tags
    @State private var tags: [String] = []
    @State private var newTag: String = ""
    
    // Checklist
    @State private var checklistItems: [ChecklistItem] = []
    @State private var newChecklistTitle: String = ""
    @State private var isReorderingChecklist: Bool = false
    
    // Map / Location
    @State private var isMapSheet: Bool = false
    @State private var locationList = [CLLocationCoordinate2D]()
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522),
                           span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2))
    )
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var selectedLocationName: String = "No Location Selected"
    
    @StateObject private var locationManager = LocationManager()
    @State private var permissionDenied = false
    
    // Validation
    @State private var showValidation: Bool = false
    
    // Map search
    @State private var searchQuery: String = ""
    @State private var searchResults: [MKLocalSearchCompletion] = []
    private let searchCompleter = MKLocalSearchCompleter()
    @State private var searchDelegate: SearchCompleterDelegate?
    
    // For center-drop feature
    @State private var mapCenter: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522)
    
    var onSave: () -> Void
    
    var body: some View {
        VStack {
            Form {
                NoteSectionView(
                    title: $title,
                    desc: $desc,
                    isPinned: $isPinned,
                    showValidation: $showValidation,
                    onValidate: validate
                )
                
                TagsSectionView(
                    tags: $tags,
                    newTag: $newTag,
                    onAdd: addTag,
                    onDelete: deleteTag
                )
                
                ChecklistSectionView(
                    checklistItems: $checklistItems,
                    newChecklistTitle: $newChecklistTitle,
                    isReorderingChecklist: $isReorderingChecklist,
                    onAdd: addChecklistItem,
                    onToggle: toggleChecklist,
                    onDelete: deleteChecklistItem,
                    onMove: moveChecklistItem
                )
                
                // MARK: - Location Section
                Section("Location") {
                    HStack(spacing: 10) {
                        Button {
                            openMapPicker()
                        } label: {
                            Label("Add Location", systemImage: "mappin.and.ellipse")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button {
                            useCurrentLocation()
                        } label: {
                            Label("Current", systemImage: "location.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    if let location = selectedLocation {
                        Map(position: $position) {
                            Marker(selectedLocationName, coordinate: location)
                        }
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        Button(role: .destructive) {
                            withAnimation {
                                selectedLocation = nil
                                selectedLocationName = "No Location Selected"
                            }
                        } label: {
                            Label("Clear Location", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Text("No location selected")
                            .foregroundColor(.secondary)
                    }
                }
                
                PhotosSectionView(
                    selectedItems: $selectedItems,
                    selectedImages: $selectedImages,
                    selectedImagesData: $selectedImagesData,
                    onMoveImage: moveImage
                )
                
                VideosSectionView(
                    selectedVideoItem: $selectedVideoItem,
                    selectedVideo: $selectedVideo,
                    onSaveVideoToDocuments: saveVideoToDocuments,
                    onThumbnail: videoThumbnail
                )
            }
            .onChange(of: selectedItems) { _, newItems in
                Task { await loadSelectedImages(newItems) }
            }
            .onChange(of: selectedVideoItem) { _, newItem in
                Task {
                    if let item = newItem, let url = try? await item.loadTransferable(type: URL.self) {
                        selectedVideo = await saveVideoToDocuments(url: url)
                    }
                }
            }
            .onAppear {
                locationManager.checkPermissionStatus()
                setupSearchCompleter()
            }
            .onChange(of: locationManager.userLocation) { location in
                if let userLocation = location {
                    zoomToUserLocation(userLocation)
                }
            }
            .onChange(of: locationManager.permissionDenied) { denied in
                permissionDenied = denied
            }
        }
        .navigationTitle("Add Notes")
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $isMapSheet, content: {
            MapSheetView(
                isMapSheet: $isMapSheet,
                position: $position,
                selectedLocation: $selectedLocation,
                selectedLocationName: $selectedLocationName,
                locationList: $locationList,
                mapCenter: $mapCenter,
                searchQuery: $searchQuery,
                searchResults: $searchResults,
                searchCompleter: searchCompleter,
                onFetchLocationName: fetchLocationName,
                onSelectSearchCompletion: selectSearchCompletion,
                onDropPinAtCenter: dropPinAtCenter
            )
        })
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "chevron.backward")
                        Text("Cancel")
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if validate() {
                        let noteItem = NotesItem(
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            desc: desc.trimmingCharacters(in: .whitespacesAndNewlines),
                            isPinned: isPinned,
                            location: selectedLocation,
                            images: selectedImagesData,
                            videoURL: selectedVideo,
                            tags: tags,
                            checklist: checklistItems,
                            createdAt: Date(),
                            updatedAt: Date()
                        )
                        context.insert(noteItem)
                        try? context.save()
                        onSave()
                        dismiss()
                    } else {
                        showValidation = true
                    }
                } label: {
                    Text("Save")
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
    
    // MARK: - Validation
    private func validate() -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return false }
        guard trimmedTitle.count <= 80 else { return false }
        guard desc.count <= 500 else { return false }
        return true
    }
    
    // MARK: - Map helpers and actions
    
    private func openMapPicker() {
        if locationManager.permissionGranted {
            isMapSheet = true
            if let userLocation = locationManager.userLocation {
                zoomToUserLocation(userLocation)
            }
        } else {
            locationManager.requestLocationPermission()
            isMapSheet = true // allow user to open and see map, will center on default if no permission yet
        }
    }
    
    private func useCurrentLocation() {
        if let loc = locationManager.userLocation?.coordinate {
            selectedLocation = loc
            fetchLocationName(for: loc) { name in
                self.selectedLocationName = name ?? "Unknown"
            }
            if let userLoc = locationManager.userLocation {
                zoomToUserLocation(userLoc)
            }
        } else {
            locationManager.requestLocationPermission()
        }
    }
    
    private func dropPinAtCenter() {
        let coord = mapCenter
        selectedLocation = coord
        fetchLocationName(for: coord) { name in
            self.selectedLocationName = name ?? "Unknown"
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
        self.mapCenter = coordinate
    }
    
    // MARK: - Media helpers
    
    private func saveVideoToDocuments(url: URL) async -> URL? {
        do {
            let data = try Data(contentsOf: url)
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fileName = "video-\(UUID().uuidString).\(url.pathExtension)"
            let fileURL = documentsDirectory.appendingPathComponent(fileName)
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Error saving video: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func videoThumbnail(for url: URL) -> UIImage? {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        do {
            let cg = try generator.copyCGImage(at: CMTime(seconds: 1, preferredTimescale: 600), actualTime: nil)
            return UIImage(cgImage: cg)
        } catch {
            return nil
        }
    }
    
    private func compressImageData(_ data: Data, maxDimension: CGFloat, quality: CGFloat) async -> Data? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let image = UIImage(data: data) else {
                    continuation.resume(returning: nil)
                    return
                }
                let resized = image.resized(maxDimension: maxDimension)
                let compressed = resized.jpegData(compressionQuality: quality)
                continuation.resume(returning: compressed)
            }
        }
    }
    
    private func loadSelectedImages(_ newItems: [PhotosPickerItem]) async {
        selectedImages.removeAll()
        for item in newItems {
            if let image = try? await item.loadTransferable(type: Image.self) {
                selectedImages.append(image)
            }
        }
        var imageDataArray = [Data]()
        for item in newItems {
            if let data = try? await item.loadTransferable(type: Data.self),
               let compressed = await compressImageData(data, maxDimension: 1600, quality: 0.7) {
                imageDataArray.append(compressed)
            }
        }
        selectedImagesData = imageDataArray
    }
    
    // MARK: - Search Completer
    
    private func setupSearchCompleter() {
        searchCompleter.resultTypes = .address
        searchCompleter.region = MKCoordinateRegion(
            center: (locationManager.userLocation?.coordinate) ?? CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522),
            span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
        )
        let delegate = SearchCompleterDelegate { completions in
            self.searchResults = completions
        }
        self.searchDelegate = delegate
        searchCompleter.delegate = delegate
    }
    
    private func selectSearchCompletion(_ completion: MKLocalSearchCompletion) {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        search.start { response, _ in
            if let item = response?.mapItems.first {
                let coordinate = item.placemark.coordinate
                selectedLocation = coordinate
                selectedLocationName = item.name ?? "Selected"
                self.position = .region(MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)))
                self.mapCenter = coordinate
            }
        }
    }
    
    // MARK: - Reorder helper for images
    private func moveImage(from source: Int, to destination: Int) {
        guard source != destination,
              source >= 0, source < selectedImagesData.count,
              destination >= 0, destination < selectedImagesData.count else { return }
        withAnimation {
            let item = selectedImagesData.remove(at: source)
            selectedImagesData.insert(item, at: destination)
        }
    }
    
    // MARK: - Tags
    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !tags.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            tags.append(trimmed)
        }
        newTag = ""
    }
    private func deleteTag(_ tag: String) {
        if let idx = tags.firstIndex(of: tag) {
            tags.remove(at: idx)
        }
    }
    
    // MARK: - Checklist
    private func addChecklistItem() {
        let trimmed = newChecklistTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        checklistItems.append(ChecklistItem(title: trimmed, isDone: false))
        newChecklistTitle = ""
    }
    private func toggleChecklist(_ item: ChecklistItem) {
        if let idx = checklistItems.firstIndex(where: { $0.id == item.id }) {
            checklistItems[idx].isDone.toggle()
        }
    }
    private func deleteChecklistItem(at offsets: IndexSet) {
        checklistItems.remove(atOffsets: offsets)
    }
    private func moveChecklistItem(from source: IndexSet, to destination: Int) {
        checklistItems.move(fromOffsets: source, toOffset: destination)
    }
}

// MARK: - Subviews

private struct NoteSectionView: View {
    @Binding var title: String
    @Binding var desc: String
    @Binding var isPinned: Bool
    @Binding var showValidation: Bool
    var onValidate: () -> Bool
    
    var body: some View {
        Section("Note") {
            HStack {
                TextField("Title", text: $title)
                    .onChange(of: title) { _ in
                        if showValidation { _ = onValidate() }
                    }
                Text("\(title.count)/80")
                    .foregroundColor(title.count > 80 ? .red : .secondary)
                    .font(.footnote)
            }
            .onChange(of: title) { _, new in
                if new.count > 80 {
                    title = String(new.prefix(80))
                }
            }
            
            VStack(alignment: .leading) {
                TextField("Description", text: $desc, axis: .vertical)
                    .lineLimit(3...6)
                    .onChange(of: desc) { _ in
                        if showValidation { _ = onValidate() }
                    }
                Text("\(desc.count)/500")
                    .foregroundColor(desc.count > 500 ? .red : .secondary)
                    .font(.footnote)
            }
            .onChange(of: desc) { _, new in
                if new.count > 500 {
                    desc = String(new.prefix(500))
                }
            }
            
            Toggle("Pin this note", isOn: $isPinned)
        }
    }
}

private struct TagsSectionView: View {
    @Binding var tags: [String]
    @Binding var newTag: String
    var onAdd: () -> Void
    var onDelete: (String) -> Void
    
    var body: some View {
        Section("Tags") {
            HStack {
                TextField("Add a tag", text: $newTag)
                    .onSubmit(onAdd)
                Button("Add") { onAdd() }
                    .buttonStyle(.borderedProminent)
            }
            if !tags.isEmpty {
                WrapTagsView(tags: tags, onDelete: onDelete)
            } else {
                Text("No tags yet").foregroundColor(.secondary)
            }
        }
    }
}

private struct ChecklistSectionView: View {
    @Binding var checklistItems: [ChecklistItem]
    @Binding var newChecklistTitle: String
    @Binding var isReorderingChecklist: Bool
    
    var onAdd: () -> Void
    var onToggle: (ChecklistItem) -> Void
    var onDelete: (IndexSet) -> Void
    var onMove: (IndexSet, Int) -> Void
    
    var body: some View {
        Section("Checklist") {
            HStack {
                TextField("New checklist item", text: $newChecklistTitle)
                    .onSubmit(onAdd)
                Button("Add") { onAdd() }
                    .buttonStyle(.bordered)
            }
            if checklistItems.isEmpty {
                Text("No checklist items").foregroundColor(.secondary)
            } else {
                List {
                    ForEach(checklistItems) { item in
                        HStack {
                            Button {
                                onToggle(item)
                            } label: {
                                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(item.isDone ? .green : .gray)
                            }
                            .buttonStyle(.plain)
                            TextField("Item", text: Binding(
                                get: { item.title },
                                set: { new in
                                    if let idx = checklistItems.firstIndex(where: { $0.id == item.id }) {
                                        checklistItems[idx].title = new
                                    }
                                }
                            ))
                        }
                    }
                    .onDelete(perform: onDelete)
                    .onMove(perform: onMove)
                }
                .environment(\.editMode, .constant(isReorderingChecklist ? .active : .inactive))
                Toggle("Reorder checklist", isOn: $isReorderingChecklist)
            }
        }
    }
}

private struct MapSheetView: View {
    @Binding var isMapSheet: Bool
    @Binding var position: MapCameraPosition
    @Binding var selectedLocation: CLLocationCoordinate2D?
    @Binding var selectedLocationName: String
    @Binding var locationList: [CLLocationCoordinate2D]
    @Binding var mapCenter: CLLocationCoordinate2D
    
    @Binding var searchQuery: String
    @Binding var searchResults: [MKLocalSearchCompletion]
    let searchCompleter: MKLocalSearchCompleter
    
    var onFetchLocationName: (CLLocationCoordinate2D, @escaping (String?) -> Void) -> Void
    var onSelectSearchCompletion: (MKLocalSearchCompletion) -> Void
    var onDropPinAtCenter: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                // Search field
                TextField("Search place", text: $searchQuery)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    .onChange(of: searchQuery) { _, new in
                        searchCompleter.queryFragment = new
                    }
                
                // Live search results
                if !searchResults.isEmpty {
                    List {
                        ForEach(searchResults, id: \.self) { completion in
                            Button {
                                onSelectSearchCompletion(completion)
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(completion.title).font(.body)
                                    Text(completion.subtitle).font(.caption).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 180)
                }
                
                ZStack {
                    MapReader { proxy in
                        Map(position: $position) {
                            if let location = selectedLocation {
                                Marker(selectedLocationName, coordinate: location)
                            }
                        }
                        .mapControls {
                            MapScaleView()
                            MapCompass()
                            MapPitchToggle()
                            MapUserLocationButton()
                        }
                        .onMapCameraChange(frequency: .continuous) { context in
                            mapCenter = context.region.center
                        }
                        .onTapGesture { point in
                            if let coord = proxy.convert(point, from: .local) {
                                selectedLocation = coord
                                locationList.append(coord)
                                position = .region(MKCoordinateRegion(center: coord, span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)))
                                onFetchLocationName(coord) { name in
                                    selectedLocationName = name ?? "Unknown"
                                }
                            }
                        }
                    }
                    
                    // Center crosshair + drop button
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button {
                                onDropPinAtCenter()
                            } label: {
                                Label("Drop Pin at Center", systemImage: "mappin.and.ellipse")
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Capsule())
                            }
                            .padding()
                        }
                    }
                    
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundColor(.blue.opacity(0.7))
                        .padding(6)
                        .background(Circle().fill(Color.white.opacity(0.8)))
                        .overlay(
                            Image(systemName: "mappin")
                                .foregroundColor(.red)
                                .offset(y: -16)
                        )
                        .allowsHitTesting(false)
                }
            }
            .navigationTitle("Pick a Location")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear") {
                        selectedLocation = nil
                        selectedLocationName = "No Location Selected"
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add Location") {
                        isMapSheet = false
                    }
                    .disabled(selectedLocation == nil)
                }
            }
        }
    }
}

private class SearchCompleterDelegate: NSObject, MKLocalSearchCompleterDelegate {
    private let onUpdate: ([MKLocalSearchCompletion]) -> Void
    init(onUpdate: @escaping ([MKLocalSearchCompletion]) -> Void) {
        self.onUpdate = onUpdate
    }
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        onUpdate(completer.results)
    }
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        onUpdate([])
    }
}

private struct WrapTagsView: View {
    let tags: [String]
    let onDelete: (String) -> Void
    
    var body: some View {
        FlexibleWrap(alignment: .leading, spacing: 8, lineSpacing: 8) {
            ForEach(tags, id: \.self) { tag in
                HStack(spacing: 6) {
                    Text(tag)
                        .font(.caption)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Capsule().fill(Color.blue.opacity(0.15)))
                    Button {
                        onDelete(tag)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// Simple flexible wrap layout for tags
private struct FlexibleWrap<Content: View>: View {
    let alignment: HorizontalAlignment
    let spacing: CGFloat
    let lineSpacing: CGFloat
    @ViewBuilder let content: Content
    
    init(alignment: HorizontalAlignment = .leading, spacing: CGFloat = 8, lineSpacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.alignment = alignment
        self.spacing = spacing
        self.lineSpacing = lineSpacing
        self.content = content()
    }
    
    var body: some View {
        _FlexibleWrap(alignment: alignment, spacing: spacing, lineSpacing: lineSpacing) {
            content
        }
    }
}

private struct _FlexibleWrap: Layout {
    let alignment: HorizontalAlignment
    let spacing: CGFloat
    let lineSpacing: CGFloat
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth {
                currentX = 0
                currentY += lineHeight + lineSpacing
                lineHeight = 0
            }
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }
        return CGSize(width: maxWidth, height: currentY + lineHeight)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = 0
        var currentY: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0
        
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.width {
                currentX = 0
                currentY += lineHeight + lineSpacing
                lineHeight = 0
            }
            sub.place(at: CGPoint(x: bounds.minX + currentX, y: currentY), proposal: ProposedViewSize(size))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

// MARK: - Media Sections Implementations

private struct PhotosSectionView: View {
    @Binding var selectedItems: [PhotosPickerItem]
    @Binding var selectedImages: [Image]
    @Binding var selectedImagesData: [Data]
    var onMoveImage: (Int, Int) -> Void
    
    var body: some View {
        Section("Photos") {
            PhotosPicker(selection: $selectedItems, matching: .images) {
                Label("Select Photos", systemImage: "photo.on.rectangle.angled")
            }
            if selectedImagesData.isEmpty {
                Text("No photos selected").foregroundColor(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(selectedImagesData.enumerated()), id: \.offset) { index, data in
                            if let ui = UIImage(data: data) {
                                VStack(spacing: 6) {
                                    Image(uiImage: ui)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    
                                    HStack(spacing: 8) {
                                        Button {
                                            if index > 0 {
                                                onMoveImage(index, index - 1)
                                            }
                                        } label: {
                                            Image(systemName: "arrow.left.circle")
                                        }
                                        .disabled(index == 0)
                                        
                                        Button {
                                            if index < selectedImagesData.count - 1 {
                                                onMoveImage(index, index + 1)
                                            }
                                        } label: {
                                            Image(systemName: "arrow.right.circle")
                                        }
                                        .disabled(index == selectedImagesData.count - 1)
                                        
                                        Button(role: .destructive) {
                                            selectedImagesData.remove(at: index)
                                            if index < selectedImages.count { selectedImages.remove(at: index) }
                                        } label: {
                                            Image(systemName: "trash")
                                        }
                                    }
                                    .buttonStyle(.borderless)
                                    .font(.caption)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Button(role: .destructive) {
                    selectedImages.removeAll()
                    selectedImagesData.removeAll()
                    selectedItems.removeAll()
                } label: {
                    Label("Clear Photos", systemImage: "trash")
                }
            }
        }
    }
}

private struct VideosSectionView: View {
    @Binding var selectedVideoItem: PhotosPickerItem?
    @Binding var selectedVideo: URL?
    
    let onSaveVideoToDocuments: (URL) async -> URL?
    let onThumbnail: (URL) -> UIImage?
    
    var body: some View {
        Section("Video") {
            PhotosPicker(selection: $selectedVideoItem, matching: .videos) {
                Label(selectedVideo == nil ? "Select Video" : "Change Video", systemImage: "video.fill.badge.plus")
            }
            
            if let url = selectedVideo {
                VStack(alignment: .leading, spacing: 8) {
                    if let thumb = onThumbnail(url) {
                        Image(uiImage: thumb)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 160)
                            .clipped()
                            .cornerRadius(10)
                            .overlay(alignment: .center) {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 44))
                                    .foregroundColor(.white.opacity(0.85))
                                    .shadow(radius: 4)
                            }
                    } else {
                        Text(url.lastPathComponent)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VideoPlayer(player: AVPlayer(url: url))
                        .frame(height: 220)
                        .cornerRadius(10)
                    
                    Button(role: .destructive) {
                        selectedVideo = nil
                        selectedVideoItem = nil
                    } label: {
                        Label("Remove Video", systemImage: "trash")
                    }
                }
            } else {
                Text("No video selected").foregroundColor(.secondary)
            }
        }
    }
}

extension UIImage {
    func resized(maxDimension: CGFloat) -> UIImage {
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return self }
        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext() ?? self
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
