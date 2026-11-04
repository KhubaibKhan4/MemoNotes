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

/// Creates a new note, or edits `editingNote` when one is passed in.
struct AddNotes: View {
    
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    /// The note being edited, or `nil` when adding a new one.
    var editingNote: NotesItem? = nil
    /// Folder for a new note (the folder being viewed on Home).
    var defaultFolder: NoteFolder? = nil
    var onSave: () -> Void = {}
    
    // Media selection
    @State private var selectedItems = [PhotosPickerItem]()
    @State private var selectedImagesData = [Data]()
    @State private var selectedVideo: URL?
    @State private var selectedVideoItem: PhotosPickerItem?
    @State private var isLoadingVideo = false
    /// The video the note had before editing; only deleted from disk once the edit is saved.
    @State private var originalVideoURL: URL?
    @State private var didLoadNote = false
    
    // Inputs
    @State private var title: String = ""
    /// The formatted note body. Its plain text is saved to `desc`.
    @State private var richDesc = AttributedString()
    @AppStorage("FontSize") private var fontSize = 16.0
    @Environment(\.fontResolutionContext) private var fontContext
    
    @State private var isPinned: Bool = false
    @State private var folder: NoteFolder?
    
    // Reminder
    @State private var hasReminder: Bool = false
    @State private var reminderDate: Date = .nextHour
    @State private var showNotificationsOffAlert: Bool = false
    
    // Tags
    @State private var tags: [String] = []
    @State private var newTag: String = ""
    @State private var suggestedTags: [String] = []
    @State private var isSuggestingTags = false
    @State private var tagSuggestionMessage: String?
    
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
    
    var body: some View {
        VStack {
            Form {
                NoteSectionView(
                    title: $title,
                    richDesc: $richDesc,
                    baseSize: fontSize,
                    isPinned: $isPinned,
                    folder: $folder,
                    showValidation: $showValidation,
                    onValidate: validate
                )
                
                ReminderSectionView(
                    hasReminder: $hasReminder,
                    reminderDate: $reminderDate
                )
                .onChange(of: hasReminder) { _, isOn in
                    guard isOn else { return }
                    Task {
                        if !(await ReminderScheduler.ensurePermission()) {
                            hasReminder = false
                            showNotificationsOffAlert = true
                        }
                    }
                }
                
                TagsSectionView(
                    tags: $tags,
                    newTag: $newTag,
                    suggestedTags: suggestedTags,
                    isSuggesting: isSuggestingTags,
                    suggestionMessage: tagSuggestionMessage,
                    canSuggest: NoteAI.isSupported,
                    onAdd: addTag,
                    onDelete: deleteTag,
                    onSuggest: suggestTags,
                    onAcceptSuggestion: acceptSuggestedTag
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
                    selectedImagesData: $selectedImagesData,
                    onMoveImage: moveImage
                )
                
                VideosSectionView(
                    selectedVideoItem: $selectedVideoItem,
                    selectedVideo: $selectedVideo,
                    isLoading: isLoadingVideo,
                    onThumbnail: videoThumbnail
                )
            }
            .onChange(of: selectedItems) { _, newItems in
                guard !newItems.isEmpty else { return }
                Task { await loadSelectedImages(newItems) }
            }
            .onChange(of: selectedVideoItem) { _, newItem in
                guard let newItem else { return }
                isLoadingVideo = true
                Task {
                    let picked = try? await newItem.loadTransferable(type: PickedVideo.self)
                    if let picked { selectedVideo = picked.url }
                    isLoadingVideo = false
                    selectedVideoItem = nil
                }
            }
            .onChange(of: selectedVideo) { oldValue, newValue in
                // A video picked during this session that gets replaced or removed is no longer needed.
                if let oldValue, oldValue != newValue, oldValue != originalVideoURL {
                    MediaStore.deleteVideo(oldValue)
                }
            }
            .onAppear {
                loadEditingNoteIfNeeded()
                locationManager.checkPermissionStatus()
                setupSearchCompleter()
            }
            .onChange(of: locationManager.userLocation) { _, location in
                if let userLocation = location {
                    zoomToUserLocation(userLocation)
                }
            }
            .onChange(of: locationManager.permissionDenied) { _, denied in
                permissionDenied = denied
            }
        }
        .navigationTitle(editingNote == nil ? "Add Note" : "Edit Note")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled()
        .alert("Notifications Are Off", isPresented: $showNotificationsOffAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Allow notifications for this app in the Settings app to get reminders.")
        }
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
                    cancel()
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
                        save()
                    } else {
                        showValidation = true
                    }
                } label: {
                    Text("Save")
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoadingVideo)
            }
        }
    }
    
    // MARK: - Load / Save
    
    private func loadEditingNoteIfNeeded() {
        guard !didLoadNote else { return }
        guard let note = editingNote else {
            didLoadNote = true
            folder = defaultFolder
            return
        }
        didLoadNote = true
        folder = note.folder
        title = note.title
        richDesc = RichTextCoder.decode(note.richText, fallback: note.desc, baseSize: fontSize)
        isPinned = note.isPinned
        tags = note.tags
        // Edit copies so that Cancel leaves the saved checklist untouched.
        checklistItems = note.checklist.map { ChecklistItem(title: $0.title, isDone: $0.isDone) }
        selectedImagesData = note.images ?? []
        selectedVideo = note.playableVideoURL
        originalVideoURL = selectedVideo
        if let date = note.reminderDate, date > Date() {
            hasReminder = true
            reminderDate = date
        }
        if let location = note.location {
            selectedLocation = location
            position = .region(MKCoordinateRegion(center: location, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)))
            mapCenter = location
            fetchLocationName(for: location) { name in
                selectedLocationName = name ?? "Unknown"
            }
        }
    }
    
    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = RichTextCoder.trimmed(richDesc)
        let trimmedDesc = String(body.characters)
        let richData = RichTextCoder.encode(body, context: fontContext, baseSize: fontSize)
        let images = selectedImagesData.isEmpty ? nil : selectedImagesData
        let reminder = hasReminder ? reminderDate : nil
        let savedNote: NotesItem
        
        if let note = editingNote {
            savedNote = note
            note.reminderDate = reminder
            note.title = trimmedTitle
            note.desc = trimmedDesc
            note.richText = richData
            note.isPinned = isPinned
            note.folder = folder
            note.tags = tags
            note.location = selectedLocation
            note.images = images
            note.videoURL = selectedVideo
            let oldChecklist = note.checklist
            note.checklist = checklistItems
            oldChecklist.forEach { context.delete($0) }
            note.updatedAt = Date()
            if originalVideoURL != selectedVideo {
                MediaStore.deleteVideo(originalVideoURL)
            }
        } else {
            let noteItem = NotesItem(
                title: trimmedTitle,
                desc: trimmedDesc,
                isPinned: isPinned,
                location: selectedLocation,
                images: images,
                videoURL: selectedVideo,
                tags: tags,
                checklist: checklistItems,
                createdAt: Date(),
                updatedAt: Date()
            )
            noteItem.reminderDate = reminder
            noteItem.richText = richData
            noteItem.folder = folder
            context.insert(noteItem)
            savedNote = noteItem
        }
        try? context.save()
        ReminderScheduler.schedule(savedNote)
        Haptics.success()
        onSave()
        dismiss()
    }
    
    private func cancel() {
        // Don't leave a video on disk that was picked but never saved.
        if selectedVideo != originalVideoURL {
            MediaStore.deleteVideo(selectedVideo)
        }
        dismiss()
    }
    
    // MARK: - Validation
    private func validate() -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return false }
        guard trimmedTitle.count <= 80 else { return false }
        guard richDesc.characters.count <= NoteSectionView.maxBodyLength else { return false }
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
    
    /// Adds newly picked photos after the ones the note already has.
    private func loadSelectedImages(_ newItems: [PhotosPickerItem]) async {
        for item in newItems {
            if let data = try? await item.loadTransferable(type: Data.self),
               let compressed = await compressImageData(data, maxDimension: 1600, quality: 0.7) {
                selectedImagesData.append(compressed)
            }
        }
        // Clear the picker so the next pick adds photos instead of replacing them.
        selectedItems = []
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
    /// Asks Apple Intelligence for tags based on the title and text.
    private func suggestTags() {
        if case .unavailable(let message) = NoteAI.status {
            tagSuggestionMessage = message
            return
        }
        let noteTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let noteBody = String(richDesc.characters)
        guard !noteTitle.isEmpty || !noteBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            tagSuggestionMessage = "Write a title or some text first."
            return
        }
        isSuggestingTags = true
        tagSuggestionMessage = nil
        Task {
            do {
                let found = try await NoteAI.suggestTags(title: noteTitle, body: noteBody, existing: tags)
                suggestedTags = found
                if found.isEmpty { tagSuggestionMessage = "No new tags to suggest." }
            } catch {
                tagSuggestionMessage = NoteAI.message(for: error)
            }
            isSuggestingTags = false
        }
    }
    
    private func acceptSuggestedTag(_ tag: String) {
        if !tags.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) {
            tags.append(tag)
        }
        suggestedTags.removeAll { $0 == tag }
        Haptics.tap()
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

private struct ReminderSectionView: View {
    @Binding var hasReminder: Bool
    @Binding var reminderDate: Date
    
    var body: some View {
        Section {
            Toggle(isOn: $hasReminder.animation()) {
                Label("Remind me", systemImage: "bell")
            }
            if hasReminder {
                DatePicker("Time", selection: $reminderDate, in: Date()...)
            }
        } header: {
            Text("Reminder")
        } footer: {
            if hasReminder {
                Text("You'll get a notification at this time.")
            }
        }
    }
}

private struct NoteSectionView: View {
    static let maxBodyLength = 10_000
    
    @Binding var title: String
    @Binding var richDesc: AttributedString
    var baseSize: CGFloat
    @Binding var isPinned: Bool
    @Binding var folder: NoteFolder?
    @Binding var showValidation: Bool
    var onValidate: () -> Bool
    
    var body: some View {
        Section("Note") {
            HStack {
                TextField("Title", text: $title)
                    .onChange(of: title) { _, _ in
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
            
            VStack(alignment: .leading, spacing: 4) {
                RichTextEditor(text: $richDesc, baseSize: baseSize)
                let count = richDesc.characters.count
                if count > Self.maxBodyLength * 9 / 10 {
                    Text("\(count)/\(Self.maxBodyLength)")
                        .foregroundColor(count > Self.maxBodyLength ? .red : .secondary)
                        .font(.footnote)
                }
            }
            
            Toggle("Pin this note", isOn: $isPinned)
            FolderPicker(selection: $folder)
        }
    }
}

private struct TagsSectionView: View {
    @Binding var tags: [String]
    @Binding var newTag: String
    var suggestedTags: [String]
    var isSuggesting: Bool
    var suggestionMessage: String?
    var canSuggest: Bool
    var onAdd: () -> Void
    var onDelete: (String) -> Void
    var onSuggest: () -> Void
    var onAcceptSuggestion: (String) -> Void
    
    var body: some View {
        Section {
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
            if canSuggest {
                Button(action: onSuggest) {
                    HStack {
                        Label("Suggest Tags", systemImage: "sparkles")
                        if isSuggesting {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isSuggesting)
                if !suggestedTags.isEmpty {
                    FlexibleWrap(spacing: 8) {
                        ForEach(suggestedTags, id: \.self) { tag in
                            Button {
                                onAcceptSuggestion(tag)
                            } label: {
                                Label(tag, systemImage: "plus")
                                    .font(.subheadline)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Capsule().strokeBorder(Color.accentColor.opacity(0.6)))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Add tag \(tag)")
                        }
                    }
                }
                if let suggestionMessage {
                    Text(suggestionMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Tags")
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
    @Binding var selectedImagesData: [Data]
    var onMoveImage: (Int, Int) -> Void
    
    var body: some View {
        Section("Photos") {
            PhotosPicker(selection: $selectedItems, matching: .images) {
                Label(selectedImagesData.isEmpty ? "Select Photos" : "Add Photos", systemImage: "photo.on.rectangle.angled")
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
    
    let isLoading: Bool
    let onThumbnail: (URL) -> UIImage?
    
    var body: some View {
        Section("Video") {
            PhotosPicker(selection: $selectedVideoItem, matching: .videos) {
                Label(selectedVideo == nil ? "Select Video" : "Change Video", systemImage: "video.fill.badge.plus")
            }
            .disabled(isLoading)
            
            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Loading video…").foregroundColor(.secondary)
                }
            } else if let url = selectedVideo {
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
