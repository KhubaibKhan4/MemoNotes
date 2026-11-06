//
//  AudioTranscription.swift
//  Turns a recorded .m4a file into text, on-device when possible.
//

import Foundation
import Speech

/// On-device speech recognition for a saved audio file.
///
/// The recognizer uses the system locale. It requires `requiresOnDeviceRecognition`
/// to be supported for the current locale; if it isn't, we fall back to the cloud
/// recognizer, which still needs the user's permission.
enum AudioTranscription {

    /// Asks the system for speech-recognition permission. Returns `true` if granted.
    static func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    /// Transcribes `url`. Runs on-device when the current locale supports it.
    /// Throws if permission is denied or recognition fails.
    static func transcribe(fileAt url: URL) async throws -> String {
        guard await requestPermission() else {
            throw TranscriptionError.permissionDenied
        }
        let locale = Locale.current
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            // Fall back to English if the device locale isn't supported.
            guard let fallback = SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
                  fallback.isAvailable else {
                throw TranscriptionError.unavailable
            }
            return try await run(recognizer: fallback, url: url)
        }
        return try await run(recognizer: recognizer, url: url)
    }

    private static func run(recognizer: SFSpeechRecognizer, url: URL) async throws -> String {
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        request.shouldReportPartialResults = false

        return try await withCheckedThrowingContinuation { continuation in
            // The task can call back several times; we only resume once.
            var finished = false
            _ = recognizer.recognitionTask(with: request) { result, error in
                if finished { return }
                if let error {
                    finished = true
                    continuation.resume(throwing: error)
                    return
                }
                guard let result, result.isFinal else { return }
                finished = true
                continuation.resume(returning: result.bestTranscription.formattedString)
            }
        }
    }
}

enum TranscriptionError: LocalizedError {
    case permissionDenied
    case unavailable

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            String(localized: "Speech recognition is off. Turn it on in Settings to transcribe voice notes.")
        case .unavailable:
            String(localized: "Speech recognition isn't available on this device.")
        }
    }
}
