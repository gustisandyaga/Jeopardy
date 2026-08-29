//
//  AudioPlayerController.swift
//  Jeopardy
//
//  Created by Gusti Sandyaga Putra Wardhana on 21/08/26.
//

import AVFoundation
import Combine

// MARK: - Audio playback

/// Drives an AVAudioPlayer and publishes playback state (position, duration,
/// playing/finished) so AudioPlayerView can show a scrubber and a "Finished"
/// indicator once playback completes.
final class AudioPlayerController: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    @Published var isFinished = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0

    private var player: AVAudioPlayer?
    private var timer: Timer?

    func load(data: Data) {
        do {
            let player = try AVAudioPlayer(data: data)
            player.delegate = self
            player.prepareToPlay()
            self.player = player
            duration = player.duration
        } catch {
            print("AudioPlayerController: failed to load audio — \(error.localizedDescription)")
        }
    }

    func play() {
        guard let player else { return }
        isFinished = false
        player.play()
        isPlaying = true
        startTimer()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
    }

    /// Distinct from pause: resets playback position back to the start.
    func stop() {
        player?.stop()
        player?.currentTime = 0
        currentTime = 0
        isPlaying = false
        isFinished = false
        stopTimer()
    }

    func seek(to time: TimeInterval) {
        player?.currentTime = time
        currentTime = time
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let player = self.player else { return }
            self.currentTime = player.currentTime
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isPlaying = false
            self.isFinished = true
            self.currentTime = 0
            self.stopTimer()
        }
    }

    func teardown() {
        stopTimer()
        player?.stop()
    }
}
