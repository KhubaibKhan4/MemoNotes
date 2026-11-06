//
//  AudioRecorder.swift
//  Records a voice note to an .m4a file in Documents.
//

import Foundation
import AVFoundation
import Observation

@MainActor
@Observable
final class AudioRecorder: NSObject {

    /// `true` while a recording is in progress.
    private(set) var isRecording = false
    /// Seconds of the current recording, updated ~10× per second.
    private(set) var elapsed: TimeInterval = 0
    /// Normalized microphone level (0…1) for a simple meter in the UI.
    private(set) var level: Float = 0

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private(set) var currentURL: URL?

    /// Asks for microphone permission and starts recording. Throws if the
    /// user denies, or if the audio session can't be configured.
    func start() async throws {
        guard !isRecording else { return }
        guard await AVAudioApplication.requestRecordPermission() else {
            throw AudioRecorderError.permissionDenied
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true, options: [])

        let url = MediaStore.newAudioURL()
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        ]
        let rec = try AVAudioRecorder(url: url, settings: settings)
        rec.delegate = self
        rec.isMeteringEnabled = true
        guard rec.record() else {
            throw AudioRecorderError.couldNotStart
        }
        recorder = rec
        currentURL = url
        isRecording = true
        elapsed = 0
        level = 0
        startTimer()
    }

    /// Stops the recording. Returns the finished file's URL, or `nil`
    /// if nothing was recorded.
    func stop() -> URL? {
        guard isRecording, let rec = recorder else { return nil }
        rec.stop()
        stopTimer()
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        let url = currentURL
        recorder = nil
        return url
    }

    /// Cancels the recording and deletes the file.
    func cancel() {
        guard let rec = recorder else { return }
        rec.stop()
        rec.deleteRecording()
        stopTimer()
        isRecording = false
        recorder = nil
        currentURL = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private func startTimer() {
        timer?.invalidate()
        // Weak self: the timer schedules on the main run loop; without this
        // the recorder outlives the view that uses it.
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard let rec = recorder, rec.isRecording else { return }
        elapsed = rec.currentTime
        rec.updateMeters()
        // averagePower is in dBFS: -160 (silent) to 0 (max). Map to 0…1.
        let dB = rec.averagePower(forChannel: 0)
        let clamped = max(dB, -50)
        level = (clamped + 50) / 50
    }
}

extension AudioRecorder: AVAudioRecorderDelegate {}

enum AudioRecorderError: LocalizedError {
    case permissionDenied
    case couldNotStart

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            String(localized: "Microphone access is off. Turn it on in Settings to record voice notes.")
        case .couldNotStart:
            String(localized: "Couldn't start recording. Try again in a moment.")
        }
    }
}
