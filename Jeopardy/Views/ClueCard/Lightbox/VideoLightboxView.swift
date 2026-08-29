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
        ZStack(alignment: .topLeading) {
            Color.black
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { dismiss() }

            Color.clear
                .aspectRatio(aspectRatio, contentMode: .fit)
                .padding(40)
                .overlay { VideoPlayer(player: player) }
                .allowsHitTesting(true)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.85))
                    .shadow(radius: 4)
            }
            .buttonStyle(.plain)
            .padding(24)
        }
        .frame(
            width: (NSScreen.main?.visibleFrame.width ?? 1200) * 0.92,
            height: (NSScreen.main?.visibleFrame.height ?? 800) * 0.92
        )
    }
}
