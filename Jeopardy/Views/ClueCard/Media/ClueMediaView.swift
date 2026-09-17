//
//  ExpandingClueImageView.swift
//  Jeopardy
//
//  Created by Gusti Sandyaga Putra Wardhana on 16/09/26.
//


//
//  ClueMediaView.swift
//  Jeopardy
//
//  Lives in Views/ClueCard/Media/. Decides which media view to show for a
//  clue (image/video/audio — at most one is ever set, see Clue.swift) and
//  provides the tappable, auto-sized image view used for both the main
//  clue image and the answer image. Split out of the old ClueCard.swift —
//  see PROJECT.md's architecture map.
//

import SwiftUI

/// Auto-expanding, tappable image view. Sized from the image's *real*
/// aspect ratio (like VideoClueView does for video) rather than a flat
/// max-height cap, so wide/tall images get proportionally more room — this
/// pushes the question/answer content below it naturally, since it all
/// lives in the same VStack. Tapping opens ImageLightboxView for a full,
/// zoomable look (pinch/scroll to zoom, drag to pan).
struct ExpandingClueImageView: View {
    let imageData: Data
    var maxWidth: CGFloat = 700
    var maxHeight: CGFloat = 500

    @State private var isShowingLightbox = false

    var body: some View {
        if let nsImage = NSImage(data: imageData) {
            Button {
                isShowingLightbox = true
            } label: {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: maxWidth, maxHeight: maxHeight)
                    .cornerRadius(12)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.caption)
                            .padding(8)
                            .background(.black.opacity(0.55), in: Circle())
                            .foregroundColor(.white)
                            .padding(10)
                    }
            }
            .buttonStyle(.plain)
            .help("Click to zoom in")
            .sheet(isPresented: $isShowingLightbox) {
                ImageLightboxView(nsImage: nsImage)
            }
        }
    }
}

struct ClueMediaView: View {
    let clue: Clue

    var body: some View {
        Group {
            if let imageData = clue.imageData {
                ExpandingClueImageView(imageData: imageData)
            } else if let videoFileName = clue.videoFileName {
                VideoClueView(filename: videoFileName)
            } else if let audioData = clue.audioData {
                AudioPlayerView(audioData: audioData)
                    .frame(maxWidth: 400)
            }
        }
        .padding()
    }
}