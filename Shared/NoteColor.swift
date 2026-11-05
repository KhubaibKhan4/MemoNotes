//
//  NoteColor.swift
//  Shared by the app and the widgets.
//

import SwiftUI

/// Colors a note's card can be tinted with. Stored by name in `NotesItem.colorName`.
enum NoteColor: String, CaseIterable, Identifiable {
    case red, orange, yellow, green, teal, blue, purple, pink

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .teal: .teal
        case .blue: .blue
        case .purple: .purple
        case .pink: .pink
        }
    }

    var title: String {
        switch self {
        case .red: String(localized: "Red")
        case .orange: String(localized: "Orange")
        case .yellow: String(localized: "Yellow")
        case .green: String(localized: "Green")
        case .teal: String(localized: "Teal")
        case .blue: String(localized: "Blue")
        case .purple: String(localized: "Purple")
        case .pink: String(localized: "Pink")
        }
    }
}

extension NotesItem {
    var noteColor: NoteColor? {
        get { colorName.flatMap(NoteColor.init(rawValue:)) }
        set { colorName = newValue?.rawValue }
    }
}
