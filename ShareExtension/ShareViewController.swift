//
//  ShareViewController.swift
//  ShareExtension
//
//  Shows "CloudNote AI" in the share sheet of other apps (WhatsApp, Safari, Photos…)
//  and saves what was shared as a note or a task.
//

import UIKit
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        let model = ShareModel(
            onDone: { [weak self] in self?.extensionContext?.completeRequest(returningItems: nil) },
            onCancel: { [weak self] in
                self?.extensionContext?.cancelRequest(withError: CocoaError(.userCancelled))
            }
        )
        let host = UIHostingController(rootView: ShareView(model: model))
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        host.didMove(toParent: self)

        let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        Task { await model.load(from: items) }
    }
}

// MARK: - Reading what was shared

/// Text, links and images pulled out of the share sheet's items.
struct SharedContent {
    var texts: [String] = []
    var links: [URL] = []
    var images: [Data] = []

    /// Text and links combined into one block, without repeating a link that is
    /// already part of the text (WhatsApp sends both).
    var combinedText: String {
        var parts = texts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let joined = parts.joined(separator: "\n")
        for link in links where !joined.contains(link.absoluteString) {
            parts.append(link.absoluteString)
        }
        return parts.joined(separator: "\n\n")
    }

    static func read(from items: [NSExtensionItem]) async -> SharedContent {
        var content = SharedContent()
        for item in items {
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    if let data = await loadImage(provider) { content.images.append(data) }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    if let url = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL,
                       !url.isFileURL {
                        content.links.append(url)
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    if let text = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String {
                        content.texts.append(text)
                    }
                }
            }
            // Some apps only describe the item (for example a page title).
            if content.texts.isEmpty, let text = item.attributedContentText?.string, !text.isEmpty {
                content.texts.append(text)
            }
        }
        return content
    }

    /// Loads an image and shrinks it like the app does, to stay within the
    /// Share Extension's memory limit and keep the database small.
    private static func loadImage(_ provider: NSItemProvider) async -> Data? {
        let data: Data? = await withCheckedContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                continuation.resume(returning: data)
            }
        }
        guard let data, let image = UIImage(data: data) else { return nil }
        let maxSide: CGFloat = 1600
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.7)
    }
}

// MARK: - Model

@MainActor
final class ShareModel: ObservableObject {
    enum Kind: String, CaseIterable {
        case note = "Note"
        case task = "Task"
    }

    @Published var isLoading = true
    @Published var kind: Kind = .note
    @Published var title = ""
    @Published var body = ""
    @Published var tag = ""
    @Published var images: [Data] = []
    @Published var errorMessage: String?
    /// Folders to file a note in: (id, name). Empty when there are none.
    @Published var folders: [(id: String, name: String)] = []
    /// Remembered between shares, so WhatsApp messages keep landing in the same folder.
    @Published var folderID: String = SharedStore.sharedDefaults.string(forKey: "ShareFolderID") ?? ""

    private let onDone: () -> Void
    private let onCancel: () -> Void

    init(onDone: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.onDone = onDone
        self.onCancel = onCancel
    }

    var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    func load(from items: [NSExtensionItem]) async {
        let content = await SharedContent.read(from: items)
        let text = content.combinedText
        if text.isEmpty {
            title = content.images.isEmpty ? "String(localized: " : (content.images.count == 1 ? ")Photo" : String(localized: "\(content.images.count) Photos"))
        } else {
            let split = NoteText.split(text)
            title = split.title
            body = split.body
        }
        images = content.images
        loadFolders()
        isLoading = false
    }

    private func loadFolders() {
        guard SharedStore.storeURL != nil,
              let container = try? SharedStore.makeContainer(syncWithICloud: false) else { return }
        let descriptor = FetchDescriptor<NoteFolder>(sortBy: [SortDescriptor(\.name)])
        folders = ((try? container.mainContext.fetch(descriptor)) ?? []).map { ($0.id, $0.name) }
        if !folders.contains(where: { $0.id == folderID }) { folderID = "" }
    }

    func save() {
        guard SharedStore.storeURL != nil else {
            errorMessage = String(localized: "Saving from other apps isn't available yet. Open CloudNote AI, then try again.")
            return
        }
        let trimmedTitle = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(NoteText.maxTitleLength))
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let container = try SharedStore.makeContainer(syncWithICloud: false)
            let context = container.mainContext
            switch kind {
            case .note:
                let tagName = tag.trimmingCharacters(in: .whitespacesAndNewlines)
                let note = NotesItem(
                    title: trimmedTitle,
                    desc: trimmedBody,
                    isPinned: false,
                    images: images.isEmpty ? nil : images,
                    tags: tagName.isEmpty ? [] : [tagName]
                )
                if !folderID.isEmpty {
                    let id = folderID
                    var descriptor = FetchDescriptor<NoteFolder>(predicate: #Predicate { $0.id == id })
                    descriptor.fetchLimit = 1
                    note.folder = try? context.fetch(descriptor).first
                }
                context.insert(note)
                SharedStore.sharedDefaults.set(folderID, forKey: "ShareFolderID")
            case .task:
                context.insert(TodoItem(title: trimmedTitle, isCompleted: false, notes: trimmedBody))
            }
            try context.save()
            SharedStore.reloadWidgets()
            onDone()
        } catch {
            errorMessage = String(localized: "Couldn't save: \(error.localizedDescription)")
        }
    }

    func cancel() {
        onCancel()
    }
}

// MARK: - View

struct ShareView: View {
    @ObservedObject var model: ShareModel

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Save as", selection: $model.kind) {
                        ForEach(ShareModel.Kind.allCases, id: \.self) { kind in
                            Text(kind.rawValue).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(model.kind == .note ? "Note" : "Task") {
                    TextField("Title", text: $model.title)
                    TextField(model.kind == .note ? "Text" : "Notes", text: $model.body, axis: .vertical)
                        .lineLimit(3...10)
                }

                if model.kind == .note {
                    if !model.images.isEmpty {
                        Section("Photos") {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(Array(model.images.enumerated()), id: \.offset) { _, data in
                                        if let image = UIImage(data: data) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 72, height: 72)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                    }
                                }
                            }
                        }
                    }
                    if !model.folders.isEmpty {
                        Section {
                            Picker("Folder", selection: $model.folderID) {
                                Text("None").tag("")
                                ForEach(model.folders, id: \.id) { folder in
                                    Text(folder.name).tag(folder.id)
                                }
                            }
                        }
                    }
                    Section("Tag") {
                        TextField("Optional, e.g. WhatsApp", text: $model.tag)
                            .textInputAutocapitalization(.never)
                    }
                } else if !model.images.isEmpty {
                    Section {
                        Text("Photos are only saved with notes.")
                            .foregroundStyle(.secondary)
                    }
                }

                if let error = model.errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
            .overlay {
                if model.isLoading {
                    ProgressView()
                }
            }
            .navigationTitle("CloudNote AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { model.cancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { model.save() }
                        .disabled(!model.canSave)
                }
            }
        }
    }
}
