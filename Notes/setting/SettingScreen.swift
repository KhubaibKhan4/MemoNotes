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
    
    @AppStorage("isDarkMode") private var isDark : Bool = false
    @State private var themeText: String = "Light Mode"
    
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
                        Toggle(isOn: $isDark) {
                            Text(themeText)
                        }.toggleStyle(.switch)
                            .onChange(of: isDark) { oldValue, newValue in
                                print("Color Scheme Changed \(newValue)")
                                if newValue  {
                                    themeText = "Dark Mode"
                                }else {
                                    themeText = "Light Mode"
                                }
                                isDark = newValue
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
                    themeText = isDark ? "Dark Mode" : "Light Mode"
                }
            }
                .preferredColorScheme(isDark ? .dark : .light)
            .navigationTitle("Setting")
                
        }
    }
}
