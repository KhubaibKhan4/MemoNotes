//
//  NoteTemplates.swift
//  Notes
//
//  Ready-made starting points for new notes.
//

import Foundation

struct NoteTemplate: Identifiable {
    let id: String
    let name: String
    let symbol: String
    /// Builds the title at the moment the template is used (e.g. today's date).
    let title: () -> String
    let body: String
    let checklist: [String]
    let tags: [String]

    private static var today: String {
        Date().formatted(date: .abbreviated, time: .omitted)
    }

    static let all: [NoteTemplate] = [
        NoteTemplate(
            id: "meeting", name: "Meeting Notes", symbol: "person.3",
            title: { "Meeting – \(today)" },
            body: "Attendees:\n\nAgenda:\n• \n\nNotes:\n\nDecisions:\n",
            checklist: ["Send follow-up", "Share notes with the team"],
            tags: ["meeting"]
        ),
        NoteTemplate(
            id: "shopping", name: "Shopping List", symbol: "cart",
            title: { "Shopping List" },
            body: "",
            checklist: ["Milk", "Bread", "Eggs", "Fruit"],
            tags: ["shopping"]
        ),
        NoteTemplate(
            id: "journal", name: "Daily Journal", symbol: "book",
            title: { "Journal – \(today)" },
            body: "How I feel today:\n\nWhat went well:\n\nWhat I'm grateful for:\n• \n\nTomorrow I want to:\n",
            checklist: [],
            tags: ["journal"]
        ),
        NoteTemplate(
            id: "todo", name: "To-Do List", symbol: "checklist",
            title: { "To-Do – \(today)" },
            body: "",
            checklist: ["Task 1", "Task 2", "Task 3"],
            tags: ["todo"]
        ),
        NoteTemplate(
            id: "travel", name: "Travel Packing", symbol: "suitcase",
            title: { "Trip Packing" },
            body: "Destination:\nDates:\n",
            checklist: ["Passport / ID", "Phone charger", "Clothes", "Toiletries", "Medicines"],
            tags: ["travel"]
        ),
        NoteTemplate(
            id: "idea", name: "Idea", symbol: "lightbulb",
            title: { "New Idea" },
            body: "The idea:\n\nWhy it matters:\n\nNext steps:\n• \n",
            checklist: [],
            tags: ["idea"]
        ),
    ]
}
