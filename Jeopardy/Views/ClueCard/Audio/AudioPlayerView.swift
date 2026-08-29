//
//  AudioPlayerView.swift
//  Jeopardy
//
//  Created by Gusti Sandyaga Putra Wardhana on 21/08/26.
//

import SwiftUI
import Combine
import AVFoundation

struct AudioPlayerView: View {
    let audioData: Data
    @StateObject private var controller = AudioPlayerController()

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: volumeIcon)
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                Slider(value: $controller.volume, in: 0...1)
            }
            
            HStack(spacing: 16) {
                Button(action: togglePlayPause) {
                    Image(systemName: controller.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .resizable()
                        .frame(width: 44, height: 44)
                        .foregroundColor(.yellow)
                }
                .buttonStyle(.plain)

                Button(action: controller.stop) {
                    Image(systemName: "stop.circle.fill")
                        .resizable()
                        .frame(width: 36, height: 36)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Stop and reset to the beginning")

                VStack(alignment: .leading, spacing: 4) {
                    Text("Audio Clue")
                        .font(.headline)
                    Text(statusText)
                        .font(.subheadline)
                        .foregroundColor(controller.isFinished ? .green : .secondary)
                }

                Spacer()
            }

            HStack(spacing: 8) {
                Text(formatTime(controller.currentTime))
                    .font(.caption)
                    .monospacedDigit()
                Slider(
                    value: Binding(
                        get: { controller.currentTime },
                        set: { controller.seek(to: $0) }
                    ),
                    in: 0...max(controller.duration, 0.01)
                )
                Text(formatTime(controller.duration))
                    .font(.caption)
                    .monospacedDigit()
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            controller.load(data: audioData)
        }
        .onDisappear {
            controller.teardown()
        }
    }

    private var statusText: String {
        if controller.isFinished { return "Finished" }
        if controller.isPlaying { return "Now Playing…" }
        return "Ready to Play"
    }
    
    private var volumeIcon: String {
        switch controller.volume {
        case 0: return "speaker.slash.fill"
        case ..<0.5: return "speaker.wave.1.fill"
        default: return "speaker.wave.2.fill"
        }
    }

    private func togglePlayPause() {
        if controller.isPlaying {
            controller.pause()
        } else {
            controller.play()
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite, time >= 0 else { return "0:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
