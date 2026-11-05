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
            id: "meeting", name: String(localized: "Meeting Notes"), symbol: "person.3",
            title: { String(localized: "Meeting – \(today)") },
            body: String(localized: "Attendees:\n\nAgenda:\n• \n\nNotes:\n\nDecisions:\n"),
            checklist: [String(localized: "Send follow-up"), String(localized: "Share notes with the team")],
            tags: ["meeting"]
        ),
        NoteTemplate(
            id: "shopping", name: String(localized: "Shopping List"), symbol: "cart",
            title: { String(localized: "Shopping List") },
            body: "",
            checklist: [String(localized: "Milk"), String(localized: "Bread"), String(localized: "Eggs"), String(localized: "Fruit")],
            tags: ["shopping"]
        ),
        NoteTemplate(
            id: "journal", name: String(localized: "Daily Journal"), symbol: "book",
            title: { String(localized: "Journal – \(today)") },
            body: String(localized: "How I feel today:\n\nWhat went well:\n\nWhat I'm grateful for:\n• \n\nTomorrow I want to:\n"),
            checklist: [],
            tags: ["journal"]
        ),
        NoteTemplate(
            id: "todo", name: String(localized: "To-Do List"), symbol: "checklist",
            title: { String(localized: "To-Do – \(today)") },
            body: "",
            checklist: [String(localized: "Task 1"), String(localized: "Task 2"), String(localized: "Task 3")],
            tags: ["todo"]
        ),
        NoteTemplate(
            id: "travel", name: String(localized: "Travel Packing"), symbol: "suitcase",
            title: { String(localized: "Trip Packing") },
            body: String(localized: "Destination:\nDates:\n"),
            checklist: [String(localized: "Passport / ID"), String(localized: "Phone charger"), String(localized: "Clothes"), String(localized: "Toiletries"), String(localized: "Medicines")],
            tags: ["travel"]
        ),
        NoteTemplate(
            id: "idea", name: String(localized: "Idea"), symbol: "lightbulb",
            title: { String(localized: "New Idea") },
            body: String(localized: "The idea:\n\nWhy it matters:\n\nNext steps:\n• \n"),
            checklist: [],
            tags: ["idea"]
        ),
    ]
}
