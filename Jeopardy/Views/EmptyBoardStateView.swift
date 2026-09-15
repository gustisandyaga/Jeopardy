//
//  EmptyBoardStateView.swift
//  Jeopardy
//
//  Created by Gusti Sandyaga Putra Wardhana on 10/09/26.
//


//
//  EmptyBoardStateView.swift
//  Jeopardy
//
//  Shown in place of the category/clue grid when the board has no clues
//  yet. Gives the Host three big, visually distinct entry points instead
//  of relying on the small toolbar icons — Nielsen's "recognition rather
//  than recall" — and groups them as one card (Gestalt's law of common
//  region) so they read as "here's how to get started" rather than three
//  unrelated buttons floating in an empty page.
//
//  Deliberately NOT three identical tiles: each one has its own accent
//  color and icon weight so the row doesn't collapse into a single flat
//  block. Pure uniformity is a known weakness of over-applying Gestalt
//  grouping — it can read as monotonous / lower perceived affordance for
//  each individual action, which is the opposite of what we want here.
//

import SwiftUI

struct EmptyBoardStateView: View {
    var onCreateDummyBoard: () -> Void
    var onImportBoard: (() -> Void)?   // nil hides the tile (e.g. non-macOS)
    var onAddClue: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Image(systemName: "square.grid.3x3.topleft.filled")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundColor(.gray.opacity(0.7))
                Text("Your Board is Empty")
                    .font(.title2.bold())
                    .foregroundColor(.black)
                Text("Get started with a sample board, load a saved one, or add your first clue.")
                    .font(.subheadline)
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
            }

            HStack(alignment: .top, spacing: 20) {
                EmptyStateTile(
                    icon: "square.grid.3x3.fill",
                    title: "5 × 5 Sample Board",
                    subtitle: "Start with placeholder categories and clues",
                    tint: .blue,
                    action: onCreateDummyBoard
                )

                if let onImportBoard {
                    EmptyStateTile(
                        icon: "square.and.arrow.up.fill",
                        title: "Import Board",
                        subtitle: "Load a previously saved .json board",
                        tint: .purple,
                        action: onImportBoard
                    )
                }

                EmptyStateTile(
                    icon: "plus.circle.fill",
                    title: "Add a Clue",
                    subtitle: "Build your board one clue at a time",
                    tint: .orange,
                    action: onAddClue
                )
            }
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct EmptyStateTile: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 64, height: 64)
                    .background(tint.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: tint.opacity(0.35), radius: isHovering ? 10 : 5, y: 3)

                VStack(spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(20)
            .frame(width: 190, height: 190)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isHovering ? tint.opacity(0.5) : Color.secondary.opacity(0.15), lineWidth: isHovering ? 2 : 1)
            )
            .scaleEffect(isHovering ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) { isHovering = hovering }
        }
    }
}

#Preview("Full Options") {
    EmptyBoardStateView(
        onCreateDummyBoard: {},
        onImportBoard: {}, // Providing empty brackets shows the tile
        onAddClue: {}
    )
}

#Preview("No Import Tile") {
    EmptyBoardStateView(
        onCreateDummyBoard: {},
        onImportBoard: nil, // Passing nil hides the tile
        onAddClue: {}
    )
}
