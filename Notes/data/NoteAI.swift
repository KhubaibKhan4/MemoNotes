//
//  NoteAI.swift
//  Notes
//
//  AI features using Apple's on-device model (Foundation Models framework).
//  Runs on the iPhone itself: free, no account or API key, and notes never
//  leave the device. Needs an iPhone that supports Apple Intelligence.
//

import Foundation
import FoundationModels

// MARK: - Structured results

@Generable
struct NoteSummary {
    @Guide(description: "A short summary of the note in one to three sentences.")
    var summary: String

    @Guide(description: "The most important points from the note, each a short phrase.", .count(0...5))
    var keyPoints: [String]
}

@Generable
struct TagSuggestions {
    @Guide(description: "Short topic tags for the note, one or two lowercase words each.", .count(1...5))
    var tags: [String]
}

@Generable
struct ActionItems {
    @Guide(description: "Concrete things to do that are mentioned in the note, each a short imperative phrase such as 'Book flights'. Empty if there are none.", .count(0...12))
    var items: [String]
}

// MARK: - Service

enum NoteAI {

    enum Status: Equatable {
        case available
        /// The device can never run Apple Intelligence: hide AI features.
        case unsupported
        /// Temporarily unavailable (turned off or still downloading): explain why.
        case unavailable(String)
    }

    static var status: Status {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(.deviceNotEligible):
            return .unsupported
        case .unavailable(.appleIntelligenceNotEnabled):
            return .unavailable("Turn on Apple Intelligence in the Settings app to use AI features.")
        case .unavailable(.modelNotReady):
            return .unavailable("Apple Intelligence is still getting ready on this iPhone. Try again in a little while.")
        case .unavailable:
            return .unavailable("AI features aren't available right now.")
        }
    }

    /// Hide AI buttons entirely on devices that can't run Apple Intelligence.
    static var isSupported: Bool { status != .unsupported }

    private static let instructions = """
        You help people with their personal notes. Work only with the note you are given. \
        Do not invent facts that are not in the note. Answer in the same language as the note.
        """

    /// The on-device model has a small context window, so long notes are shortened.
    private static func prompt(_ task: String, title: String, body: String) -> String {
        let clipped = body.count > 3000 ? String(body.prefix(3000)) + "…" : body
        return """
            \(task)

            Note title: \(title)
            Note text:
            \(clipped.isEmpty ? "(empty)" : clipped)
            """
    }

    static func summarize(title: String, body: String) async throws -> NoteSummary {
        let session = LanguageModelSession(instructions: instructions)
        return try await session.respond(
            to: prompt("Summarize this note.", title: title, body: body),
            generating: NoteSummary.self
        ).content
    }

    /// Suggested tags, lowercased and without ones the note already has.
    static func suggestTags(title: String, body: String, existing: [String]) async throws -> [String] {
        let session = LanguageModelSession(instructions: instructions)
        let result = try await session.respond(
            to: prompt("Suggest tags that describe what this note is about.", title: title, body: body),
            generating: TagSuggestions.self
        ).content
        let taken = Set(existing.map { $0.lowercased() })
        var seen = Set<String>()
        return result.tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty && !taken.contains($0) && seen.insert($0).inserted }
    }

    static func actionItems(title: String, body: String) async throws -> [String] {
        let session = LanguageModelSession(instructions: instructions)
        return try await session.respond(
            to: prompt("List the action items or tasks in this note.", title: title, body: body),
            generating: ActionItems.self
        ).content.items
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// A message people can understand for a failed request.
    static func message(for error: Error) -> String {
        if let error = error as? LanguageModelSession.GenerationError {
            switch error {
            case .exceededContextWindowSize:
                return String(localized: "This note is too long for the on-device model. Try a shorter note.")
            case .guardrailViolation, .refusal:
                return String(localized: "Apple Intelligence couldn't work with this note's content.")
            case .unsupportedLanguageOrLocale:
                return String(localized: "This note's language isn't supported by Apple Intelligence yet.")
            case .assetsUnavailable:
                return String(localized: "Apple Intelligence is still getting ready on this iPhone. Try again in a little while.")
            case .rateLimited:
                return String(localized: "Too many requests at once. Try again in a moment.")
            default:
                break
            }
        }
        // Other failures (including the newer error types on iOS 27) get a plain message;
        // the details go to the console for debugging.
        print("Apple Intelligence request failed: \(error)")
        return String(localized: "Apple Intelligence couldn't finish this right now. Please try again in a moment.")
    }
}
