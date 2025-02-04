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
    @State private var appVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    
    @EnvironmentObject private var appManager: AppManager
    
    var body: some View {
        NavigationView {
            Form {
                Group {
                    Section("Localization") {
                        NavigationLink(destination: CountrySelectorView(), label: {
                            Label("Languages: \(appManager.languageName)", systemImage: "globe")
                        })
                    }
                    
                    Section("Color Scheme") {
                        Toggle(isOn: $appManager.isDark) {
                            Text(themeText)
                        }.toggleStyle(.switch)
                            .onChange(of: appManager.isDark) { oldValue, newValue in
                                print("Color Scheme Changed \(newValue)")
                                themeText = newValue ? "Dark Mode" : "Light Mode"
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
                    
                    Section("App Version") {
                        HStack {
                            Label("App Version", systemImage: "info.circle")
                            Spacer()
                            Text(appVersion)
                                .foregroundColor(.gray)
                        }
                    }
                    
                }.onAppear {
                    themeText = appManager.isDark ? "Dark Mode" : "Light Mode"
                }
            }
            .preferredColorScheme(appManager.isDark ? .dark : .light)
            .navigationTitle("Settings")
        }
    }
}
