//
//  TodoItem.swift
//  Notes
//
//  Created by Muhammad Khubaib Imtiaz on 20/10/2024.
//
import SwiftData
import Foundation
import SwiftData

@Model
class TodoItem: Identifiable{
    var id: String
    var title: String
    var isCompleted: Bool
    init(title: String, isCompleted: Bool) {
        self.id = UUID().uuidString
        self.title = title
        self.isCompleted = isCompleted
    }
}
