//
//  ImageLightboxView.swift
//  Jeopardy
//
//  Created by Gusti Sandyaga Putra Wardhana on 29/08/26.
//


//
//  ImageLightboxView.swift
//  Jeopardy
//
//  Full-screen, pinch/scroll-to-zoom preview for a clue's image, reached by
//  tapping the inline image in ClueMediaView (see ExpandingClueImageView).
//  Pinch (or scroll-wheel magnify) to zoom, drag to pan once zoomed in,
//  double-tap to reset.
//

import SwiftUI

struct ImageLightboxView: View {
    let nsImage: NSImage
    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 6.0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Tapping anywhere on the backdrop (i.e. outside the image
            // itself) dismisses the lightbox, like clicking "outside" a
            // photo viewer.
            Color.black
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { dismiss() }

            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(offset)
                .padding(40)
                .gesture(SimultaneousGesture(magnifyGesture, dragGesture))
                .onTapGesture(count: 2, perform: resetZoom)
                .allowsHitTesting(true)

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

    private var magnifyGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(lastScale * value, minScale), maxScale)
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= minScale { resetZoom() }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > minScale else { return }
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                guard scale > minScale else { return }
                lastOffset = offset
            }
    }

    private func resetZoom() {
        withAnimation(.easeInOut(duration: 0.2)) {
            scale = 1.0
            lastScale = 1.0
            offset = .zero
            lastOffset = .zero
        }
    }
}
