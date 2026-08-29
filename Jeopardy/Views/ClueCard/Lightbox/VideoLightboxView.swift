//
//  VideoLightboxView.swift
//  Jeopardy
//
//  Created by Gusti Sandyaga Putra Wardhana on 29/08/26.
//


//
//  VideoLightboxView.swift
//  Jeopardy
//
//  Full-screen preview for a clue's video, reached via the expand button on
//  VideoClueView's inline (size-capped) player. Deliberately no zoom/pan
//  here — AVKit's VideoPlayer already scales to fit, and a video's natural
//  aspect ratio (unlike a photo) rarely benefits from cropping in further.
//

import AVKit
import SwiftUI

struct VideoLightboxView: View {
    let player: AVPlayer
    let aspectRatio: CGFloat
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            Color.clear
                .aspectRatio(aspectRatio, contentMode: .fit)
                .overlay { VideoPlayer(player: player) }
                .padding()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.85))
                    .shadow(radius: 4)
            }
            .buttonStyle(.plain)
            .padding(20)
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}