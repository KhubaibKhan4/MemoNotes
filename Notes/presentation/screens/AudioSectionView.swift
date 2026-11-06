//
//  AudioSectionView.swift
//  The voice-note controls in the note editor:
//  record, play back, transcribe, delete.
//

import SwiftUI

struct AudioSectionView: View {
    /// The current recording for this note. Updated as the user records or removes.
    @Binding var audioURL: URL?
    /// Transcript of `audioURL`, if the user asked for one.
    @Binding var transcript: String?

    @State private var recorder = AudioRecorder()
    @State private var player = AudioPlayer()
    @State private var isTranscribing = false
    @State private var errorMessage: String?

    var body: some View {
        Section {
            if recorder.isRecording {
                recordingRow
            } else if let url = audioURL, let resolved = MediaStore.resolveAudio(url) {
                playbackRow(url: resolved)
                transcriptRow(url: resolved)
            } else {
                startRow
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Audio")
        }
    }

    // MARK: - Rows

    private var startRow: some View {
        Button {
            Task { await startRecording() }
        } label: {
            Label {
                Text("Record voice note")
            } icon: {
                Image(systemName: "mic.circle.fill")
                    .foregroundStyle(.red)
                    .imageScale(.large)
            }
        }
    }

    private var recordingRow: some View {
        HStack(spacing: 12) {
            // Pulsing dot to make it unmistakable that recording is live.
            Circle()
                .fill(.red)
                .frame(width: 10, height: 10)
                .opacity(0.4 + Double(recorder.level) * 0.6)
                .animation(.easeInOut(duration: 0.1), value: recorder.level)
            Text(formatTime(recorder.elapsed))
                .monospacedDigit()
                .font(.body.weight(.semibold))
            Spacer()
            Button(role: .destructive) {
                recorder.cancel()
            } label: {
                Text("Cancel")
            }
            .buttonStyle(.bordered)
            Button {
                let url = recorder.stop()
                audioURL = url
                // A fresh recording invalidates the old transcript.
                transcript = nil
            } label: {
                Label("Stop", systemImage: "stop.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
    }

    private func playbackRow(url: URL) -> some View {
        HStack(spacing: 12) {
            Button {
                do {
                    try player.load(url)
                    player.toggle()
                } catch {
                    errorMessage = String(localized: "Couldn't play this recording.")
                }
            } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .imageScale(.large)
                    .font(.system(size: 32))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                ProgressView(
                    value: max(0, min(player.position, player.duration)),
                    total: max(player.duration, 0.1)
                )
                Text(formatTime(player.duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Menu {
                Button(role: .destructive) {
                    player.stop()
                    MediaStore.deleteAudio(url)
                    audioURL = nil
                    transcript = nil
                } label: {
                    Label("Remove Recording", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .imageScale(.large)
            }
        }
        .onAppear {
            try? player.load(url)
        }
    }

    @ViewBuilder
    private func transcriptRow(url: URL) -> some View {
        if let transcript, !transcript.isEmpty {
            Text(transcript)
                .font(.callout)
                .foregroundStyle(.secondary)
            Button {
                UIPasteboard.general.string = transcript
                Haptics.success()
            } label: {
                Label("Copy Transcript", systemImage: "doc.on.doc")
            }
        } else if isTranscribing {
            HStack {
                ProgressView()
                Text("Transcribing…")
                    .foregroundStyle(.secondary)
            }
        } else {
            Button {
                Task { await runTranscription(url: url) }
            } label: {
                Label("Transcribe", systemImage: "text.bubble")
            }
        }
    }

    // MARK: - Actions

    private func startRecording() async {
        errorMessage = nil
        do {
            try await recorder.start()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func runTranscription(url: URL) async {
        errorMessage = nil
        isTranscribing = true
        defer { isTranscribing = false }
        do {
            let text = try await AudioTranscription.transcribe(fileAt: url)
            transcript = text
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
