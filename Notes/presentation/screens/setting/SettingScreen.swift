//
//  SettingScreen.swift
//  Notes
//
//  Created by Muhammad Khubaib Imtiaz on 20/10/2024.
//  Redesigned with more features and modern look.
//

import SwiftUI
import StoreKit

struct SettingScreen: View {
    
    @AppStorage("FontSize") private var fontSize = 16.0
    @AppStorage("ShowLineNo") private var showLineNo = false
    @AppStorage("ShowPreview") private var showPreview = true
    @AppStorage("EnableNotifications") private var notificationsEnabled = false
    @AppStorage("EnableHaptics") private var hapticsEnabled = true
    @AppStorage("SelectedAppIcon") private var selectedAppIcon = "AppIcon"
    @State private var theme: ThemeOption = .system
    
    @Environment(\.requestReview) private var requestReview
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var appManager: AppManager
    
    @State private var appVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    @State private var showResetAlert = false
    @State private var showExportSheet = false
    @State private var showImportSheet = false
    @State private var importResult: Result<URL, Error>?
    
    var body: some View {
        NavigationStack {
            Form {
                // ---- Localization
                Section(header: Label("Localization", systemImage: "globe")) {
                    NavigationLink(destination: CountrySelectorView()) {
                        HStack {
                            Label("Language", systemImage: "globe")
                            Spacer()
                            Text(appManager.languageName)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // ---- Appearance
                Section(header: Label("Appearance", systemImage: "paintbrush")) {
                    Picker("Theme", selection: $theme) {
                        ForEach(ThemeOption.allCases, id: \.self) { option in
                            Label(option.displayName, systemImage: option.icon)
                                .tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: theme) { _, newValue in
                        // Sync with AppManager
                        appManager.isDark = (newValue == .dark)
                    }
                    
                    if UIApplication.shared.supportsAlternateIcons {
                        NavigationLink {
                            AppIconPicker(selectedIcon: $selectedAppIcon)
                        } label: {
                            Label("App Icon", systemImage: "app.dashed")
                        }
                    }
                    
                    HStack {
                        Label("Font Size", systemImage: "textformat.size")
                        Slider(value: $fontSize, in: 12...28, step: 1)
                        Text("\(Int(fontSize))pt")
                            .foregroundColor(.secondary)
                    }
                }
                
                // ---- Task/Note Viewing
                Section(header: Label("Viewing Options", systemImage: "doc.text.magnifyingglass")) {
                    Toggle(isOn: $showLineNo) {
                        Label("Show Line Numbers", systemImage: "list.number")
                    }
                    Toggle(isOn: $showPreview) {
                        Label("Show Preview", systemImage: "doc.richtext")
                    }
                }
                
                // ---- Notifications & Haptics
                Section(header: Label("Feedback", systemImage: "bell")) {
                    Toggle(isOn: $notificationsEnabled) {
                        Label("Enable Notifications", systemImage: "bell.badge")
                    }
                    .onChange(of: notificationsEnabled) { _, enabled in
                        // Show alert or request permission logic here
                    }
                    
                    Toggle(isOn: $hapticsEnabled) {
                        Label("Enable Haptics", systemImage: "waveform.path")
                    }
                }
                
                // ---- Data
                Section(header: Label("Data", systemImage: "externaldrive")) {
                    Button {
                        showExportSheet = true
                    } label: {
                        Label("Export Data", systemImage: "square.and.arrow.up")
                    }
                    .disabled(true) // Implement export logic
                    
                    Button {
                        showImportSheet = true
                    } label: {
                        Label("Import Data", systemImage: "square.and.arrow.down")
                    }
                    .disabled(true) // Implement import logic
                    
                    Button(role: .destructive) {
                        showResetAlert = true
                    } label: {
                        Label("Reset All Data", systemImage: "trash")
                    }
                }
                
                // ---- About & Support
                Section(header: Label("About", systemImage: "info.circle")) {
                    Button {
                        requestReview()
                    } label: {
                        Label("Rate This App", systemImage: "star.fill")
                    }
                    .foregroundColor(.accentColor)
                    
                    NavigationLink {
                        PirvacyPolicyView()
                    } label: {
                        Label("Privacy Policy", systemImage: "shield.lefthalf.fill")
                    }
                    
                    HStack {
                        Label("App Version", systemImage: "app.badge")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Reset All App Data?", isPresented: $showResetAlert) {
                Button("Delete All", role: .destructive) { resetAllData() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will erase all your notes, todos, and settings. This cannot be undone.")
            }
            .sheet(isPresented: $showExportSheet) {
                // Place file exporter here
            }
            .sheet(isPresented: $showImportSheet) {
                // Place file importer here
            }
            .onAppear {
                theme = appManager.isDark ? .dark : .system
            }
            .preferredColorScheme(theme == .system ? nil : (theme == .dark ? .dark : .light))
        }
    }
    
    // MARK: - Actions
    
    private func resetAllData() {
        // Implement: Remove all user data, notes, todos, and settings
        // This is application-specific.
    }
}

// MARK: - Theme Option

private enum ThemeOption: String, CaseIterable {
    case system, light, dark
    var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
    var icon: String {
        switch self {
        case .system: "circle.lefthalf.fill"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }
}

// MARK: - App Icon Picker

private struct AppIconPicker: View {
    @Binding var selectedIcon: String
    private let icons: [AppIcon] = [
        AppIcon(name: "AppIcon", displayName: "Default"),
        // Add more as you register them in Info.plist
        AppIcon(name: "AppIconDark", displayName: "Dark"),
        AppIcon(name: "AppIconLight", displayName: "Light")
    ]
    
    var body: some View {
        List(icons, id: \.name) { icon in
            HStack {
                Image(uiImage: UIImage(named: icon.name) ?? UIImage())
                    .resizable()
                    .frame(width: 60, height: 60)
                    .cornerRadius(12)
                    .shadow(radius: 2)
                Text(icon.displayName)
                Spacer()
                if selectedIcon == icon.name {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                setAppIcon(icon.name)
            }
        }
        .navigationTitle("App Icon")
    }
    
    private func setAppIcon(_ name: String) {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        let altName = name == "AppIcon" ? nil : name
        UIApplication.shared.setAlternateIconName(altName)
        selectedIcon = name
    }
}

private struct AppIcon {
    let name: String
    let displayName: String
}

// MARK: - Preview

#Preview {
    SettingScreen()
        .environmentObject(AppManager())
}

