//
//  ContentView.swift
//  Notes
//
//  Created by Muhammad Khubaib Imtiaz on 14/10/2024.
//

import SwiftUI
import SwiftData


struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @State private var isSelected : Int = 0
    @AppStorage("isPermissionGranted") var isPermissionGranted = false
    
    @State private var isSplash: Bool = true
    var body: some View {
        VStack {
            if isSplash {
                SplashScreen()
            } else {
                TabView(selection:$isSelected) {
                    Tab("Home", systemImage: "house",value: 0) {
                        HomeScreen()
                    }
                    
                    Tab("Todo", systemImage: "checklist",value: 1) {
                        TodoScreen()
                        
                    }
                    
                    Tab("Setting", systemImage: "gear",value:2) {
                        SettingScreen()
                    }
                    
                }
            }
        }.onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                isSplash = false
            }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            // Rebuild pending reminders whenever the app comes to the front. This picks up
            // reminders added or changed on other devices through iCloud, and ones lost
            // after a reinstall, restore or permission change.
            if phase == .active {
                ReminderScheduler.resync(context: context)
            }
        }
    }
}


#Preview {
    ContentView()
}
