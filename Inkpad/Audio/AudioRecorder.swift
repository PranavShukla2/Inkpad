//
//  AudioRecorder.swift
//  Inkpad
//

import AVFoundation
import SwiftData

/// Records lectures into a notebook and plays recordings back.
@Observable
final class AudioRecorder: NSObject, AVAudioPlayerDelegate {
    private(set) var isRecording = false
    private(set) var elapsed: TimeInterval = 0
    private(set) var playingRecording: Recording?
    private(set) var playbackProgress: Double = 0
    var isPermissionDenied = false

    @ObservationIgnored private var recorder: AVAudioRecorder?
    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var tickTask: Task<Void, Never>?

    // MARK: - Recording

    func startRecording() async {
        guard !isRecording else { return }
        guard await AVAudioApplication.requestRecordPermission() else {
            isPermissionDenied = true
            return
        }
        stopPlayback()

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true)

            let url = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).m4a")
            let recorder = try AVAudioRecorder(url: url, settings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            ])
            guard recorder.record() else { return }
            self.recorder = recorder
            isRecording = true
            elapsed = 0
            startTicking()
        } catch {
            print("Couldn't start recording: \(error)")
        }
    }

    /// Stops recording and saves it into the notebook.
    func stopRecording(into notebook: Notebook) {
        guard let recorder, isRecording else { return }
        let duration = recorder.currentTime
        recorder.stop()
        self.recorder = nil
        isRecording = false
        stopTicking()
        deactivateSession()

        defer { try? FileManager.default.removeItem(at: recorder.url) }
        guard let data = try? Data(contentsOf: recorder.url), duration > 0.5 else { return }
        let recording = Recording(audioData: data, duration: duration)
        notebook.modelContext?.insert(recording)
        notebook.recordings.append(recording)
    }

    // MARK: - Playback

    func togglePlayback(of recording: Recording) {
        if playingRecording == recording {
            stopPlayback()
            return
        }
        stopPlayback()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(data: recording.audioData)
            player.delegate = self
            player.play()
            self.player = player
            playingRecording = recording
            startTicking()
        } catch {
            print("Couldn't play recording: \(error)")
        }
    }

    func stopPlayback() {
        guard player != nil else { return }
        player?.stop()
        player = nil
        playingRecording = nil
        playbackProgress = 0
        stopTicking()
        deactivateSession()
    }

    func delete(_ recording: Recording) {
        if playingRecording == recording {
            stopPlayback()
        }
        recording.modelContext?.delete(recording)
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.stopPlayback()
        }
    }

    // MARK: - Progress

    private func startTicking() {
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.tick()
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
    }

    private func tick() {
        if let recorder {
            elapsed = recorder.currentTime
        }
        if let player, player.duration > 0 {
            playbackProgress = player.currentTime / player.duration
        }
    }

    private func stopTicking() {
        tickTask?.cancel()
        tickTask = nil
    }

    private func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
