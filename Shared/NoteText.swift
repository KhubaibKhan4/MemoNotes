//
//  NoteText.swift
//  Shared by the app and the Share Extension.
//

import Foundation

enum NoteText {
    static let maxTitleLength = 80

    /// Splits shared or dictated text into a note title and body:
    /// the first line becomes the title, the rest the body. A first line that is too
    /// long for a title is shortened, and the full text is kept in the body.
    static func split(_ text: String) -> (title: String, body: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = trimmed.components(separatedBy: .newlines)
        let firstLine = (lines.first ?? "").trimmingCharacters(in: .whitespaces)

        if firstLine.count <= maxTitleLength {
            let rest = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            return (firstLine, rest)
        }

        // Cut at a word boundary where possible.
        let cut = firstLine.prefix(maxTitleLength - 1)
        let shortened = cut.lastIndex(of: " ").map { String(cut[..<$0]) } ?? String(cut)
        return (shortened + "…", trimmed)
    }
}
