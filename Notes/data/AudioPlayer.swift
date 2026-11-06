//
//  AudioPlayer.swift
//  Plays back a voice note, with a progress bar you can scrub.
//

import Foundation
import AVFoundation
import Observation

@MainActor
@Observable
final class AudioPlayer: NSObject {

    private(set) var isPlaying = false
    /// Current playback position, seconds.
    private(set) var position: TimeInterval = 0
    /// Length of the loaded file, seconds. 0 until a file is loaded.
    private(set) var duration: TimeInterval = 0

    private var player: AVAudioPlayer?
    private var timer: Timer?
    private(set) var loadedURL: URL?

    func load(_ url: URL) throws {
        if loadedURL == url, player != nil { return }
        // Allow playback over the speaker even if the phone is on silent.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [])
        try? session.setActive(true, options: [])

        let p = try AVAudioPlayer(contentsOf: url)
        p.delegate = self
        p.prepareToPlay()
        player = p
        loadedURL = url
        duration = p.duration
        position = 0
    }

    func play() {
        guard let p = player else { return }
        p.play()
        isPlaying = true
        startTimer()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
    }

    func toggle() {
        isPlaying ? pause() : play()
    }

    func seek(to seconds: TimeInterval) {
        guard let p = player else { return }
        p.currentTime = max(0, min(seconds, p.duration))
        position = p.currentTime
    }

    func stop() {
        player?.stop()
        isPlaying = false
        position = 0
        stopTimer()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard let p = player else { return }
        position = p.currentTime
    }
}

extension AudioPlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully _: Bool) {
        Task { @MainActor [weak self] in
            self?.isPlaying = false
            self?.position = 0
            self?.stopTimer()
        }
    }
}
