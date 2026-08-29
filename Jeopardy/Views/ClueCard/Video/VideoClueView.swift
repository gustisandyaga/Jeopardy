//
//  VideoClueView.swift
//  Jeopardy
//
//  Created by Gusti Sandyaga Putra Wardhana on 21/08/26.
//

import AVKit
import SwiftUI

// MARK: - Video playback

/// Wraps AVKit's VideoPlayer (which already provides play/pause/scrub
/// controls) pointed at a clue's locally-copied video file.
///
/// Previously this just forced `.frame(height: 300)` with no width
/// constraint, so VideoPlayer would stretch to fill the entire clue detail
/// width while letterboxing the actual (usually much narrower, e.g. 16:9 or
/// 9:16) video — resulting in a huge band of black on either side. Instead
/// we read the video's real aspect ratio and size a "frame" around exactly
/// that shape, capped so it never gets absurdly large or small, similar to
/// how an embedded YouTube player behaves.
struct VideoClueView: View {
    let filename: String
    @State private var player: AVPlayer?
    @State private var aspectRatio: CGFloat = 16.0 / 9.0

    private let maxWidth: CGFloat = 640
    private let maxHeight: CGFloat = 360

    var body: some View {
            Group {
                if let player {
                    // 1. Let a simple background shape handle all the sizing math safely
                    Color.black
                        .aspectRatio(aspectRatio, contentMode: .fit)
                        .frame(maxWidth: maxWidth, maxHeight: maxHeight)
                        
                        // 2. Slap the video player cleanly on top
                        .overlay {
                            VideoPlayer(player: player)
                        }
                        
                        // 3. Keep all your styling on the outside
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .shadow(radius: 8)
                        .onDisappear { player.pause() }
                } else {
                    ProgressView()
                        .frame(width: maxWidth, height: maxHeight)
                }
            }
            .task {
                guard player == nil else { return }
                let url = MediaStore.url(for: filename)
                let newPlayer = AVPlayer(url: url)
                player = newPlayer
                aspectRatio = await Self.naturalAspectRatio(for: url) ?? aspectRatio
            }
        }
    /// Reads the video track's natural (orientation-corrected) size to
    /// compute width/height, falling back to the 16:9 default if the asset
    /// can't be inspected for any reason.
    private static func naturalAspectRatio(for url: URL) async -> CGFloat? {
        let asset = AVURLAsset(url: url)
        do {
            guard let track = try await asset.loadTracks(withMediaType: .video).first else { return nil }
            let size = try await track.load(.naturalSize)
            let transform = try await track.load(.preferredTransform)
            let correctedSize = size.applying(transform)
            let width = abs(correctedSize.width)
            let height = abs(correctedSize.height)
            guard width > 0, height > 0 else { return nil }
            return width / height
        } catch {
            return nil
        }
    }
}
