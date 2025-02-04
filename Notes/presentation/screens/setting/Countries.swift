//
//  Countries.swift
//  Notes
//
//  Created by Muhammad Khubaib Imtiaz on 22/12/2024.
//

import SwiftUI

struct Country: Identifiable {
    let id = UUID()
    let name: String
    let flag: String
    let language: String
    let languageCode: String
}
