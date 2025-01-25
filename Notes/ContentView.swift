//
//  ContentView.swift
//  Notes
//
//  Created by Muhammad Khubaib Imtiaz on 14/10/2024.
//

import SwiftUI
import SwiftData


struct ContentView: View {
    @State private var isSelected : Int = 0
    @AppStorage("isPermissionGranted") var isPermissionGranted = false
    var body: some View {
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
}


#Preview {
    ContentView()
}
