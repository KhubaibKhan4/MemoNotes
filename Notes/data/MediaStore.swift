//
//  MediaStore.swift
//  Notes
//

import Foundation
import CoreTransferable
import UniformTypeIdentifiers

/// Stores note videos in the app's Documents folder.
///
/// The absolute path of the app container can change between installs, updates
/// and restores, so a stored video URL is always resolved by its file name.
enum MediaStore {
    private static let videoPrefix = "video-"

    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Current location of a stored video, or `nil` if the file is gone.
    static func resolve(_ stored: URL?) -> URL? {
        guard let stored else { return nil }
        let url = documentsDirectory.appendingPathComponent(stored.lastPathComponent)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Copies a picked video into Documents and returns its new URL.
    static func importVideo(from source: URL) throws -> URL {
        let ext = source.pathExtension.isEmpty ? "mov" : source.pathExtension
        let destination = documentsDirectory.appendingPathComponent("\(videoPrefix)\(UUID().uuidString).\(ext)")
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }

    static func deleteVideo(_ stored: URL?) {
        guard let url = resolve(stored) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    static func deleteAllVideos() {
        let files = (try? FileManager.default.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.lastPathComponent.hasPrefix(videoPrefix) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    // MARK: - Audio

    private static let audioPrefix = "audio-"
    /// m4a: AAC in an MP4 container. Small files, universally playable.
    static let audioExtension = "m4a"

    /// A fresh URL inside Documents for a new recording. Caller writes to it.
    static func newAudioURL() -> URL {
        documentsDirectory.appendingPathComponent("\(audioPrefix)\(UUID().uuidString).\(audioExtension)")
    }

    static func resolveAudio(_ stored: URL?) -> URL? {
        resolve(stored)
    }

    static func deleteAudio(_ stored: URL?) {
        guard let url = resolve(stored) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    static func deleteAllAudio() {
        let files = (try? FileManager.default.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.lastPathComponent.hasPrefix(audioPrefix) {
            try? FileManager.default.removeItem(at: file)
        }
    }
}

/// A video chosen in `PhotosPicker`, already copied into Documents.
struct PickedVideo: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            // `received.file` is temporary, so copy it somewhere we own.
            PickedVideo(url: try MediaStore.importVideo(from: received.file))
        }
    }
}

extension NotesItem {
    /// The note's video at its current on-disk location.
    var playableVideoURL: URL? { MediaStore.resolve(videoURL) }
}
