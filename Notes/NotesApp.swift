//
//  NotesApp.swift
//  Notes
//
//  Created by Muhammad Khubaib Imtiaz on 14/10/2024.
//

import SwiftUI

@main
struct NotesApp: App {
    
    @StateObject var appManager: AppManager = AppManager()
    
    
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [NotesItem.self,TodoItem.self])
                .environment(\.locale, Locale(identifier: appManager.appLanguage))
                .environmentObject(appManager)
                .preferredColorScheme(appManager.isDark ? .dark : .light)
                .environment(\.locale, .init(identifier: appManager.appLanguage))
                .environment(\.layoutDirection, isRTL(langauge: appManager.appLanguage) ? .rightToLeft : .leftToRight)
        }
    }
    
    func isRTL(langauge: String) -> Bool {
        let rtlLanguage = ["ar", "he", "fa", "ur"]
        return rtlLanguage.contains(langauge)
    }
}
