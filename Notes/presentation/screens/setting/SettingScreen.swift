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
    @AppStorage(AppLockManager.enabledKey) private var appLockEnabled = false
    @AppStorage(AppLockManager.timeoutKey) private var appLockTimeout = AppLockTimeout.immediately.rawValue
    @State private var showLockUnavailableAlert = false

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
    @State private var isSignedInToICloud = FileManager.default.ubiquityIdentityToken != nil

    /// Turning App Lock on or off requires unlocking first, so nobody else can change it.
    private var appLockBinding: Binding<Bool> {
        Binding(
            get: { appLockEnabled },
            set: { newValue in
                guard newValue != appLockEnabled else { return }
                guard AppLockManager.isAvailable else {
                    showLockUnavailableAlert = true
                    return
                }
                Task {
                    let reason = newValue ? String(localized: "Turn on App Lock") : String(localized: "Turn off App Lock")
                    if await AppLockManager.authenticate(reason: reason) {
                        appLockEnabled = newValue
                        SharedStore.setAppLockEnabled(newValue)
                        if newValue {
                            // Hide notes from iPhone search while locked.
                            SpotlightIndex.deleteEverything()
                        } else {
                            SpotlightIndex.reindexEverything(from: context)
                        }
                        Haptics.success()
                    }
                }
            }
        )
    }
    
    /// The language the app is showing, in that language (e.g. "Español").
    private var currentLanguageName: String {
        let code = Bundle.main.preferredLocalizations.first ?? "en"
        let locale = Locale(identifier: code)
        return locale.localizedString(forIdentifier: code)?.capitalized(with: locale) ?? code
    }
    
    private var themeBinding: Binding<ThemeOption> {
        Binding(get: { appManager.theme }, set: { appManager.theme = $0 })
    }

    var body: some View {
        NavigationStack {
            Form {
                // ---- App header
                Section {
                    HStack(spacing: 14) {
                        Image("logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("CloudNote AI")
                                .font(.title3.bold())
                            Text("Version \(appVersion)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                }
                
                // ---- General
                Section {
                    // iOS switches the app's language itself (Settings › CloudNote AI › Language),
                    // which updates every screen, widgets and the share extension, and handles
                    // right-to-left languages.
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    } label: {
                        HStack {
                            SettingsRowLabel("Language", systemImage: "globe", color: .blue)
                            Spacer()
                            Text(currentLanguageName)
                                .foregroundColor(.secondary)
                            Image(systemName: "arrow.up.forward.app")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                } header: {
                    Text("General")
                } footer: {
                    Text("Opens Settings, where you can choose the language for CloudNote AI.")
                }

                // ---- Appearance
                Section("Appearance") {
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
                            SettingsRowLabel("App Icon", systemImage: "app.dashed", color: .indigo)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            SettingsRowLabel("Note Text Size", systemImage: "textformat.size", color: .gray)
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
                        SettingsRowLabel("Show Line Numbers", systemImage: "list.number", color: .teal)
                    }
                    Toggle(isOn: $showPreview) {
                        SettingsRowLabel("Show Preview", systemImage: "doc.richtext", color: .cyan)
                    }
                } header: {
                    Text("Viewing Options")
                } footer: {
                    Text("Line numbers appear in a note's description. Preview shows the start of each note in the notes list.")
                }

                // ---- Notifications & Haptics
                Section {
                    Toggle(isOn: $notificationsEnabled) {
                        SettingsRowLabel("Notifications", systemImage: "bell.badge.fill", color: .red)
                    }
                    .onChange(of: notificationsEnabled) { _, enabled in
                        if enabled {
                            requestNotificationPermission()
                        } else {
                            ReminderScheduler.cancelAll()
                        }
                    }

                    Toggle(isOn: $hapticsEnabled) {
                        SettingsRowLabel("Haptics", systemImage: "waveform", color: .pink)
                    }
                    .onChange(of: hapticsEnabled) { _, enabled in
                        if enabled { Haptics.tap(.medium) }
                    }
                } header: {
                    Text("Feedback")
                } footer: {
                    Text("Notifications are used for reminders on notes and todos.")
                }

                // ---- Privacy
                Section {
                    Toggle(isOn: appLockBinding) {
                        SettingsRowLabel("Lock with \(AppLockManager.methodName)", systemImage: AppLockManager.methodSymbol, color: .green)
                    }
                    if appLockEnabled {
                        Picker(selection: $appLockTimeout) {
                            ForEach(AppLockTimeout.allCases) { option in
                                Text(option.title).tag(option.rawValue)
                            }
                        } label: {
                            SettingsRowLabel("Require Unlock", systemImage: "timer", color: .green)
                        }
                    }
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("When on, your notes stay hidden until you unlock the app, including in the app switcher.")
                }
                
                // ---- iCloud
                Section {
                    HStack {
                        SettingsRowLabel("iCloud Sync", systemImage: "icloud.fill", color: .blue)
                        Spacer()
                        Text(isSignedInToICloud ? "On" : "Off")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Sync")
                } footer: {
                    if isSignedInToICloud {
                        Text("Notes, checklists, photos, todos and reminders sync to your other devices signed in to the same iCloud account. Videos stay on the device that added them.")
                    } else {
                        Text("Sign in to iCloud in the Settings app to sync notes and todos across your devices.")
                    }
                }
                
                // ---- Data
                Section {
                    Button {
                        prepareExport()
                    } label: {
                        SettingsRowLabel("Export Data", systemImage: "square.and.arrow.up", color: .orange)
                    }

                    Button {
                        showImporter = true
                    } label: {
                        SettingsRowLabel("Import Data", systemImage: "square.and.arrow.down", color: .orange)
                    }

                    Button(role: .destructive) {
                        showResetAlert = true
                    } label: {
                        SettingsRowLabel("Reset All Data", systemImage: "trash.fill", color: .red, isDestructive: true)
                    }
                } header: {
                    Text("Data")
                } footer: {
                    Text("Exports notes, photos, checklists, todos and reminders as a JSON file. Videos are not included. Importing adds notes and todos without replacing what you have.")
                }

                // ---- About & Support
                Section("About") {
                    Button {
                        requestReview()
                    } label: {
                        SettingsRowLabel("Rate This App", systemImage: "star.fill", color: .yellow)
                    }
                    .foregroundStyle(.primary)

                    NavigationLink {
                        PirvacyPolicyView()
                    } label: {
                        SettingsRowLabel("Privacy Policy", systemImage: "hand.raised.fill", color: .blue)
                    }

                }
            }
            .navigationTitle("Settings")
            .onAppear {
                syncNotificationPermission()
                isSignedInToICloud = FileManager.default.ubiquityIdentityToken != nil
            }
            .alert("Reset All App Data?", isPresented: $showResetAlert) {
                Button("Delete All", role: .destructive) { resetAllData() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(isSignedInToICloud
                     ? String(localized: "This will erase all your notes, todos, and settings — on this device and on your other devices that sync through iCloud. This cannot be undone.")
                     : String(localized: "This will erase all your notes, todos, and settings. This cannot be undone."))
            }
            .alert("App Lock Unavailable", isPresented: $showLockUnavailableAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Set up \(AppLockManager.methodName == "Passcode" ? "a device passcode" : AppLockManager.methodName) in the Settings app to lock your notes.")
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
                    resultMessage = String(localized: "Backup saved.")
                case .failure(let error):
                    resultMessage = String(localized: "Couldn't save the backup: \(error.localizedDescription)")
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
            resultMessage = String(localized: "Couldn't create the backup: \(error.localizedDescription)")
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
            let notes = added.notes == 1 ? String(localized: "1 note") : String(localized: "\(added.notes) notes")
            let todos = added.todos == 1 ? String(localized: "1 todo") : String(localized: "\(added.todos) todos")
            resultMessage = String(localized: "Imported \(notes) and \(todos).")
        } catch is DecodingError {
            resultMessage = String(localized: "This file isn't a MemoNotes backup.")
        } catch {
            resultMessage = String(localized: "Couldn't import the file: \(error.localizedDescription)")
        }
    }

    private func resetAllData() {
        do {
            try DataManager.deleteAllData(context: context)
            ReminderScheduler.cancelAll()
        } catch {
            resultMessage = String(localized: "Couldn't delete all data: \(error.localizedDescription)")
            return
        }

        // Settings back to their defaults.
        fontSize = 16
        showLineNo = false
        showPreview = true
        notificationsEnabled = false
        hapticsEnabled = true
        appLockEnabled = false
        SharedStore.setAppLockEnabled(false)
        appLockTimeout = AppLockTimeout.immediately.rawValue
        appManager.theme = .system
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
        .environmentObject(AppLockManager())
        .modelContainer(for: [NotesItem.self, TodoItem.self], inMemory: true)
}

// MARK: - Row label

/// A settings row title with a small colored icon tile, like the iOS Settings app.
struct SettingsRowLabel: View {
    let title: LocalizedStringKey
    let systemImage: String
    let color: Color
    var isDestructive = false

    init(_ title: LocalizedStringKey, systemImage: String, color: Color, isDestructive: Bool = false) {
        self.title = title
        self.systemImage = systemImage
        self.color = color
        self.isDestructive = isDestructive
    }

    var body: some View {
        Label {
            Text(title)
                .foregroundStyle(isDestructive ? Color.red : Color.primary)
        } icon: {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
    }
}
