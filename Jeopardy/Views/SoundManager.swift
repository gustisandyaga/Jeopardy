//
//  SoundManager.swift
//  Jeopardy
//
//  Created by Gusti Sandyaga Putra Wardhana on 08/05/26.
//

import AVFoundation

class SoundManager {
    static let instance = SoundManager()
    var player: AVAudioPlayer?

    func playSound(named: String) {
        // Look for the sound in the main App Bundle (Assets)
        guard let url = Bundle.main.url(forResource: named, withExtension: "mp3") else { return }

        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.play()
        } catch {
            print("Error playing sound: \(error.localizedDescription)")
        }
    }
}
