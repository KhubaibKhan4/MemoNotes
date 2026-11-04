//
//  AppManager.swift
//  Notes
//
//  Created by Muhammad Khubaib Imtiaz on 03/02/2025.
//

import SwiftUI

enum ThemeOption: String, CaseIterable {
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

    /// `nil` lets the app follow the device's appearance.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

class AppManager: ObservableObject {

    @AppStorage("themeMode") private var themeRaw: String = AppManager.initialThemeRaw() {
        didSet {
            objectWillChange.send()
        }
    }

    var theme: ThemeOption {
        get { ThemeOption(rawValue: themeRaw) ?? .system }
        set { themeRaw = newValue.rawValue }
    }

    @AppStorage("language") var appLanguage: String = "en" {
        didSet {
            objectWillChange.send()
        }
    }

    @AppStorage("languageName") var languageName: String = "English" {
        didSet {
            objectWillChange.send()
        }
    }

    /// Where a widget, control or Siri asked the app to go. Screens clear it once handled.
    @Published var pendingRoute: AppRoute?

    /// Older versions only stored an `isDark` flag; carry that choice over once.
    private static func initialThemeRaw() -> String {
        UserDefaults.standard.bool(forKey: "isDark") ? ThemeOption.dark.rawValue : ThemeOption.system.rawValue
    }
}
