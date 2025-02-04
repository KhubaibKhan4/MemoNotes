//
//  AppManager.swift
//  Notes
//
//  Created by Muhammad Khubaib Imtiaz on 03/02/2025.
//

import SwiftUI

class AppManager: ObservableObject {
    
    @AppStorage("isDark") var isDark: Bool = false {
        didSet {
            objectWillChange.send()
        }
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
}
