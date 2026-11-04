//
//  NotesApp.swift
//  Notes
//
//  Created by Muhammad Khubaib Imtiaz on 14/10/2024.
//

import SwiftUI
import SwiftData

@main
struct NotesApp: App {

    @UIApplicationDelegateAdaptor(NotificationDelegate.self) private var notificationDelegate
    @StateObject var appManager: AppManager = AppManager()
    @StateObject private var appLock = AppLockManager()

    /// Shared database. With `.automatic`, SwiftData syncs through the first iCloud
    /// container in the app's entitlements, and stays local-only when there is none.
    private let container: ModelContainer = {
        let schema = Schema([NotesItem.self, ChecklistItem.self, TodoItem.self])
        do {
            let config = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Never lock people out of their notes: fall back to local storage.
            print("iCloud store unavailable, using local storage: \(error)")
            do {
                let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
                return try ModelContainer(for: schema, configurations: [local])
            } catch {
                fatalError("Could not open the notes database: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
                .environment(\.locale, Locale(identifier: appManager.appLanguage))
                .environmentObject(appManager)
                .environmentObject(appLock)
                .preferredColorScheme(appManager.theme.colorScheme)
                .environment(\.locale, .init(identifier: appManager.appLanguage))
                .environment(\.layoutDirection, isRTL(langauge: appManager.appLanguage) ? .rightToLeft : .leftToRight)
        }
    }

    func isRTL(langauge: String) -> Bool {
        let rtlLanguage = ["ar", "he", "fa", "ur"]
        return rtlLanguage.contains(langauge)
    }
}
