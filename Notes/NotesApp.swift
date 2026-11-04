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


    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(AppDatabase.container)
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

/// The app's single connection to the notes database, also used by Siri / Shortcuts actions.
@MainActor
enum AppDatabase {
    /// Shared database in the App Group folder (see `SharedStore`). SwiftData syncs it
    /// through the first iCloud container in the app's entitlements, if there is one.
    static let container: ModelContainer = {
        // Older versions kept the database in the app's private folder; move it once
        // so the Share Extension and widgets can see existing notes.
        SharedStore.moveStoreToAppGroupIfNeeded()
        do {
            return try SharedStore.makeContainer(syncWithICloud: true)
        } catch {
            // Never lock people out of their notes: fall back to local storage.
            print("iCloud store unavailable, using local storage: \(error)")
            do {
                return try SharedStore.makeContainer(syncWithICloud: false)
            } catch {
                fatalError("Could not open the notes database: \(error)")
            }
        }
    }()
}
