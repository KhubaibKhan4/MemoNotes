//
//  SettingScreen.swift
//  Notes
//
//  Created by Muhammad Khubaib Imtiaz on 20/10/2024.
//
import SwiftUI
import StoreKit

struct SettingScreen: View {
    
    @AppStorage("FontSize") private var fontSize = 12
    @State private var showLineNo = false
    @State private var showPreview: Bool = true
    
    @Environment(\.requestReview) private var requestReview
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var themeText: String = "Light Mode"
    
    @EnvironmentObject private var appManager: AppManager
    
    var body: some View {
        NavigationView {
            Form {
                Group {
                    Section("Localization") {
                        NavigationLink(destination: CountrySelectorView(), label: {
                            Label("Languages", systemImage: "globe")
                        })
                    }
                    
                    Section("Color Scheme") {
                        Toggle(isOn: $appManager.isDark) {
                            Text(themeText)
                        }.toggleStyle(.switch)
                            .onChange(of: appManager.isDark) { oldValue, newValue in
                                print("Color Scheme Changed \(newValue)")
                                if newValue  {
                                    themeText = "Dark Mode"
                                }else {
                                    themeText = "Light Mode"
                                }
                                appManager.isDark = newValue
                            }
                    }
                    
                    Section("App Detail") {
                        Button(action: {
                            requestReview()
                        }) {
                            Label("Review", systemImage: "star")
                        }
                    }
                    
                    Section("Privacy Policy") {
                        NavigationLink(destination: PirvacyPolicyView()) {
                            Label("Privacy Policy", systemImage: "shield.fill")
                        }
                    }
                    
                }.onAppear {
                    themeText = appManager.isDark ? "Dark Mode" : "Light Mode"
                }
            }
            .preferredColorScheme(appManager.isDark ? .dark : .light)
            .navigationTitle("Setting")
        }
    }
}
