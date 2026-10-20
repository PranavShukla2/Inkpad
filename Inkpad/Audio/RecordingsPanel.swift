//
//  RecordingsPanel.swift
//  Inkpad
//

import SwiftUI

/// Record button and the notebook's recordings, shown in a popover.
struct RecordingsPanel: View {
    let notebook: Notebook
    let recorder: AudioRecorder

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recordings")
                .font(.serif(.title3))
                .foregroundStyle(Theme.ink)

            recordButton

            if recordings.isEmpty {
                Text("Record a lecture or meeting while you write. Recordings stay in this notebook.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(recordings) { recording in
                            row(for: recording)
                            Divider()
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 340, height: 400)
        .background(Theme.deskRaised)
        .alert("Microphone Access Needed", isPresented: Binding(get: { recorder.isPermissionDenied }, set: { recorder.isPermissionDenied = $0 })) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Allow Inkpad to use the microphone in Settings to record audio.")
        }
    }

    private var recordings: [Recording] {
        notebook.recordings.sorted { $0.createdAt > $1.createdAt }
    }

    private var recordButton: some View {
        Button {
            if recorder.isRecording {
                recorder.stopRecording(into: notebook)
            } else {
                Task {
                    await recorder.startRecording()
                }
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Theme.stamp)
                    if recorder.isRecording {
                        RoundedRectangle(cornerRadius: 3).fill(.white).frame(width: 12, height: 12)
                    } else {
                        Circle().fill(.white).frame(width: 12, height: 12)
                    }
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(recorder.isRecording ? "Stop Recording" : "Start Recording")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    if recorder.isRecording {
                        Text(Duration.seconds(recorder.elapsed), format: .time(pattern: .minuteSecond))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(Theme.stamp)
                    }
                }
                Spacer()
            }
            .padding(12)
            .background(Theme.desk, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact, trigger: recorder.isRecording)
    }

    private func row(for recording: Recording) -> some View {
        let isPlaying = recorder.playingRecording == recording
        return HStack(spacing: 12) {
            Button {
                recorder.togglePlayback(of: recording)
            } label: {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(Theme.stamp)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? "Pause" : "Play")

            VStack(alignment: .leading, spacing: 4) {
                Text(recording.createdAt, format: .dateTime.day().month().hour().minute())
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
                if isPlaying {
                    ProgressView(value: recorder.playbackProgress)
                        .tint(Theme.stamp)
                } else {
                    Text(Duration.seconds(recording.duration), format: .time(pattern: .minuteSecond))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Theme.inkSecondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 10)
        .contextMenu {
            Button("Delete Recording", systemImage: "trash", role: .destructive) {
                recorder.delete(recording)
            }
        }
    }
}
