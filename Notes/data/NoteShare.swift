//
//  NoteShare.swift
//  Builds a readable text version of a note for the iOS share sheet.
//  Works with any receiving app — Messages, Mail, WhatsApp, AirDrop,
//  the clipboard, anything that takes text.
//

import Foundation

enum NoteShare {

    /// Readable plain-text version of the note:
    ///   TITLE
    ///
    ///   body
    ///
    ///   - [x] checked item
    ///   - [ ] open item
    ///
    ///   Place: <location name>
    ///   Shared from CloudNote AI
    static func plainText(for note: NotesItem) -> String {
        var lines: [String] = []

        let title = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty {
            lines.append(title)
            lines.append("")
        }

        let body = note.desc.trimmingCharacters(in: .whitespacesAndNewlines)
        if !body.isEmpty {
            lines.append(body)
        }

        let checklist = note.checklist
        if !checklist.isEmpty {
            if !lines.isEmpty { lines.append("") }
            for item in checklist {
                let marker = item.isDone ? "[x]" : "[ ]"
                lines.append("- \(marker) \(item.title)")
            }
        }

        if let tags = sharedTags(note.tags) {
            lines.append("")
            lines.append(tags)
        }

        lines.append("")
        lines.append(String(localized: "Shared from CloudNote AI"))

        return lines.joined(separator: "\n")
    }

    private static func sharedTags(_ tags: [String]) -> String? {
        let clean = tags
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !clean.isEmpty else { return nil }
        return clean.map { "#\($0)" }.joined(separator: " ")
    }
}
