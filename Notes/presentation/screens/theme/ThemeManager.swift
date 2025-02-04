//
//  ThemeManager.swift
//  Notes
//
//  Created by Muhammad Khubaib Imtiaz on 26/11/2024.
//
import SwiftUI

class ThemeManager: ObservableObject {
    @Published var isDark = false
    
    func changeTheme(_ newValue: Bool) {
        isDark = newValue
    }
}
