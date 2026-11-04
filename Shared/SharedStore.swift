//
//  SharedStore.swift
//  Shared by the app, the Share Extension and the widgets.
//

import Foundation
import SwiftData
import WidgetKit

/// The notes database, kept in the App Group folder so the app, the Share Extension
/// and the widgets all read and write the same notes and todos.
enum SharedStore {

    static let appGroupID = "group.com.brikmas.aipowerednotes.sync.notes"

    static var schema: Schema {
        Schema([NotesItem.self, ChecklistItem.self, TodoItem.self, NoteFolder.self])
    }

    /// `nil` when the App Group isn't set up (missing entitlement).
    static var groupContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    /// Same file name and layout SwiftData uses by default, so moving the old store
    /// keeps its photo files (".default_SUPPORT") working.
    static var storeURL: URL? {
        groupContainerURL?.appending(path: "Library/Application Support/default.store")
    }

    /// Settings shared with the extensions (such as whether App Lock is on).
    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    /// Opens the database. Only the app syncs with iCloud; the extensions write locally
    /// and the app uploads their changes the next time it runs.
    static func makeContainer(syncWithICloud: Bool) throws -> ModelContainer {
        let cloud: ModelConfiguration.CloudKitDatabase = syncWithICloud ? .automatic : .none
        let config: ModelConfiguration
        if let storeURL {
            try? FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: cloud)
        } else {
            config = ModelConfiguration(schema: schema, cloudKitDatabase: cloud)
        }
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// Moves the database from the app's private folder into the App Group folder.
    /// Runs once, before the database is first opened; does nothing afterwards.
    static func moveStoreToAppGroupIfNeeded() {
        guard let storeURL else { return }
        let fm = FileManager.default
        let newFolder = storeURL.deletingLastPathComponent()
        try? fm.createDirectory(at: newFolder, withIntermediateDirectories: true)
        guard !fm.fileExists(atPath: storeURL.path) else { return }

        let oldFolder = URL.applicationSupportDirectory
        guard fm.fileExists(atPath: oldFolder.appending(path: "default.store").path) else { return }

        for name in ["default.store", "default.store-shm", "default.store-wal", ".default_SUPPORT"] {
            let from = oldFolder.appending(path: name)
            guard fm.fileExists(atPath: from.path) else { continue }
            do {
                try fm.moveItem(at: from, to: newFolder.appending(path: name))
            } catch {
                print("Couldn't move \(name) to the App Group: \(error)")
            }
        }
    }

    // MARK: - App Lock

    static let appLockKey = "AppLockEnabled"

    /// Widgets hide note content while App Lock is on.
    static var isAppLockEnabled: Bool {
        sharedDefaults.bool(forKey: appLockKey)
    }

    static func setAppLockEnabled(_ enabled: Bool) {
        sharedDefaults.set(enabled, forKey: appLockKey)
        reloadWidgets()
    }

    // MARK: - Widgets

    static func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}

/// Places in the app that widgets, controls and Siri can open.
enum AppRoute: Equatable {
    case newNote
    case note(id: String)
    case todos

    static let scheme = "cloudnote"

    var url: URL {
        switch self {
        case .newNote: URL(string: "\(Self.scheme)://new-note")!
        case .note(let id): URL(string: "\(Self.scheme)://note/\(id)")!
        case .todos: URL(string: "\(Self.scheme)://todos")!
        }
    }

    init?(url: URL) {
        guard url.scheme == Self.scheme else { return nil }
        switch url.host() {
        case "new-note": self = .newNote
        case "todos": self = .todos
        case "note":
            let id = url.lastPathComponent
            guard !id.isEmpty, id != "/" else { return nil }
            self = .note(id: id)
        default: return nil
        }
    }
}
