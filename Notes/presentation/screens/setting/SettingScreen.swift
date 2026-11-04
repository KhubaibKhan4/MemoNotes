//
//  SettingScreen.swift
//  Notes
//
//  Created by Muhammad Khubaib Imtiaz on 20/10/2024.
//  Redesigned with more features and modern look.
//

import SwiftUI
import SwiftData
import StoreKit
import UserNotifications
import UniformTypeIdentifiers

struct SettingScreen: View {

    @AppStorage("FontSize") private var fontSize = 16.0
    @AppStorage("ShowLineNo") private var showLineNo = false
    @AppStorage("ShowPreview") private var showPreview = true
    @AppStorage("EnableNotifications") private var notificationsEnabled = false
    @AppStorage("EnableHaptics") private var hapticsEnabled = true
    @AppStorage("SelectedAppIcon") private var selectedAppIcon = "AppIcon"

    @Environment(\.requestReview) private var requestReview
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var appManager: AppManager

    @State private var appVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    @State private var showResetAlert = false
    @State private var showNotificationsDeniedAlert = false

    // Export / import
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var exportDocument: BackupDocument?
    @State private var resultMessage: String?

    private var themeBinding: Binding<ThemeOption> {
        Binding(get: { appManager.theme }, set: { appManager.theme = $0 })
    }

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
                    Picker("Theme", selection: themeBinding) {
                        ForEach(ThemeOption.allCases, id: \.self) { option in
                            Label(option.displayName, systemImage: option.icon)
                                .tag(option)
                        }
                    }
                    .pickerStyle(.segmented)

                    if !AppIconPicker.alternateIconNames.isEmpty {
                        NavigationLink {
                            AppIconPicker(selectedIcon: $selectedAppIcon)
                        } label: {
                            Label("App Icon", systemImage: "app.dashed")
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label("Note Text Size", systemImage: "textformat.size")
                            Spacer()
                            Text("\(Int(fontSize))pt")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $fontSize, in: 12...28, step: 1)
                        Text("The quick brown fox jumps over the lazy dog.")
                            .font(.system(size: fontSize))
                            .foregroundStyle(.secondary)
                    }
                }

                // ---- Note Viewing
                Section {
                    Toggle(isOn: $showLineNo) {
                        Label("Show Line Numbers", systemImage: "list.number")
                    }
                    Toggle(isOn: $showPreview) {
                        Label("Show Preview", systemImage: "doc.richtext")
                    }
                } header: {
                    Label("Viewing Options", systemImage: "doc.text.magnifyingglass")
                } footer: {
                    Text("Line numbers appear in a note's description. Preview shows the start of each note in the notes list.")
                }

                // ---- Notifications & Haptics
                Section {
                    Toggle(isOn: $notificationsEnabled) {
                        Label("Enable Notifications", systemImage: "bell.badge")
                    }
                    .onChange(of: notificationsEnabled) { _, enabled in
                        if enabled {
                            requestNotificationPermission()
                        } else {
                            ReminderScheduler.cancelAll()
                        }
                    }

                    Toggle(isOn: $hapticsEnabled) {
                        Label("Enable Haptics", systemImage: "waveform.path")
                    }
                    .onChange(of: hapticsEnabled) { _, enabled in
                        if enabled { Haptics.tap(.medium) }
                    }
                } header: {
                    Label("Feedback", systemImage: "bell")
                } footer: {
                    Text("Notifications are used for reminders on notes and todos.")
                }

                // ---- Data
                Section {
                    Button {
                        prepareExport()
                    } label: {
                        Label("Export Data", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        showImporter = true
                    } label: {
                        Label("Import Data", systemImage: "square.and.arrow.down")
                    }

                    Button(role: .destructive) {
                        showResetAlert = true
                    } label: {
                        Label("Reset All Data", systemImage: "trash")
                    }
                } header: {
                    Label("Data", systemImage: "externaldrive")
                } footer: {
                    Text("Exports notes, photos, checklists, todos and reminders as a JSON file. Videos are not included. Importing adds notes and todos without replacing what you have.")
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
            .onAppear(perform: syncNotificationPermission)
            .alert("Reset All App Data?", isPresented: $showResetAlert) {
                Button("Delete All", role: .destructive) { resetAllData() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will erase all your notes, todos, and settings. This cannot be undone.")
            }
            .alert("Notifications Are Off", isPresented: $showNotificationsDeniedAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Allow notifications for this app in the Settings app to turn them on.")
            }
            .alert(
                "Data",
                isPresented: Binding(get: { resultMessage != nil }, set: { if !$0 { resultMessage = nil } })
            ) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(resultMessage ?? "")
            }
            .fileExporter(
                isPresented: $showExporter,
                document: exportDocument,
                contentType: .json,
                defaultFilename: DataManager.backupFileName()
            ) { result in
                switch result {
                case .success:
                    Haptics.success()
                    resultMessage = "Backup saved."
                case .failure(let error):
                    resultMessage = "Couldn't save the backup: \(error.localizedDescription)"
                }
                exportDocument = nil
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                importBackup(result)
            }
        }
    }

    // MARK: - Actions

    private func prepareExport() {
        do {
            exportDocument = BackupDocument(data: try DataManager.exportBackup(context: context))
            showExporter = true
        } catch {
            resultMessage = "Couldn't create the backup: \(error.localizedDescription)"
        }
    }

    private func importBackup(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

            let added = try DataManager.importBackup(try Data(contentsOf: url), context: context)
            ReminderScheduler.resync(context: context)
            Haptics.success()
            let notes = added.notes == 1 ? "1 note" : "\(added.notes) notes"
            let todos = added.todos == 1 ? "1 todo" : "\(added.todos) todos"
            resultMessage = "Imported \(notes) and \(todos)."
        } catch is DecodingError {
            resultMessage = "This file isn't a MemoNotes backup."
        } catch {
            resultMessage = "Couldn't import the file: \(error.localizedDescription)"
        }
    }

    private func resetAllData() {
        do {
            try DataManager.deleteAllData(context: context)
            ReminderScheduler.cancelAll()
        } catch {
            resultMessage = "Couldn't delete all data: \(error.localizedDescription)"
            return
        }

        // Settings back to their defaults.
        fontSize = 16
        showLineNo = false
        showPreview = true
        notificationsEnabled = false
        hapticsEnabled = true
        appManager.theme = .system
        appManager.appLanguage = "en"
        appManager.languageName = "English"
        if selectedAppIcon != "AppIcon" {
            UIApplication.shared.setAlternateIconName(nil)
            selectedAppIcon = "AppIcon"
        }
        Haptics.warning()
    }

    private func requestNotificationPermission() {
        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            if settings.authorizationStatus == .denied {
                notificationsEnabled = false
                showNotificationsDeniedAlert = true
                return
            }
            if await ReminderScheduler.ensurePermission() {
                ReminderScheduler.resync(context: context)
            } else {
                notificationsEnabled = false
            }
        }
    }

    /// Turns the toggle off if permission was revoked in the Settings app.
    private func syncNotificationPermission() {
        guard notificationsEnabled else { return }
        Task {
            let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            if status == .denied { notificationsEnabled = false }
        }
    }
}

// MARK: - App Icon Picker

private struct AppIconPicker: View {
    @Binding var selectedIcon: String

    /// Alternate icons declared in Info.plist (CFBundleIcons > CFBundleAlternateIcons).
    static var alternateIconNames: [String] {
        let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any]
        let alternates = icons?["CFBundleAlternateIcons"] as? [String: Any]
        return alternates?.keys.sorted() ?? []
    }

    private var icons: [String] { ["AppIcon"] + Self.alternateIconNames }

    var body: some View {
        List(icons, id: \.self) { name in
            HStack {
                Image(uiImage: UIImage(named: name) ?? UIImage())
                    .resizable()
                    .frame(width: 60, height: 60)
                    .cornerRadius(12)
                    .shadow(radius: 2)
                Text(name == "AppIcon" ? "Default" : name)
                Spacer()
                if selectedIcon == name {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                setAppIcon(name)
            }
        }
        .navigationTitle("App Icon")
    }

    private func setAppIcon(_ name: String) {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        UIApplication.shared.setAlternateIconName(name == "AppIcon" ? nil : name) { error in
            if error == nil {
                DispatchQueue.main.async { selectedIcon = name }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SettingScreen()
        .environmentObject(AppManager())
        .modelContainer(for: [NotesItem.self, TodoItem.self], inMemory: true)
}
