//
//  ClueCardView.swift
//  Jeopardy
//
//  Created by Gusti Sandyaga Putra Wardhana on 16/09/26.
//


//
//  ClueCardView.swift
//  Jeopardy
//
//  The board tile shown in BoardGridView — one clue's point value, opened/
//  answered state, and its right-click menu (edit / delete / reactivate).
//  Split out of the old ClueCard.swift, which also held the media
//  dispatcher, multiple-choice gameplay view, and the entire detail/edit
//  screen in one file — see PROJECT.md's architecture map.
//

import SwiftUI
import SwiftData

struct ClueCardView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(BoardGridDensity.storageKey) private var gridDensityRaw: String = BoardGridDensity.comfortable.rawValue
    let clue: Clue
    var onEdit: () -> Void = {}

    private var gridDensity: BoardGridDensity {
        BoardGridDensity(rawValue: gridDensityRaw) ?? .comfortable
    }

    var body: some View {
        ZStack {
            // Soft glow / halo — this card's own gradient, blurred and
            // rendered underneath the sharp card on top. Blur naturally
            // bleeds the filled shape's color beyond its own edges, so the
            // visible result is a gradual color ramp from card to
            // background over a few points, rather than a single hard
            // step. This is the actual mechanism behind why a blurred
            // rendering (e.g. World of Jeopardy) showed a much fainter
            // version of the Hermann grid illusion than a crisp one —
            // unlike cornerRadius/shadow (which softened the *geometry*
            // around the edge), this softens the edge itself. Only shown
            // in Comfortable density — in Tight, gaps are already narrow
            // enough that a blurred halo would just muddy adjacent cards
            // together rather than help. See PROJECT.md's "Design system
            // reference" section and BoardGridDensity.swift.
            if gridDensity.usesSoftEdge {
                RoundedRectangle(cornerRadius: gridDensity.cardCornerRadius)
                    .fill(cardFill)
                    .blur(radius: 10)
                    .opacity(0.6)
            }

            cardContent
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        // --- CONTEXT MENU: edit or delete this clue ---
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Edit Clue", systemImage: "pencil")
            }
            Button(role: .destructive) {
                deleteClue()
            } label: {
                Label("Delete Clue", systemImage: "trash")
            }
            Button(role: .confirm) {
                reactivateClue()
            } label: {
                Label("Reactivate Clue", systemImage: "button.programmable")
            }
        }
    }

    /// The sharp, fully-opaque card itself — sits on top of the blurred
    /// halo in `body`, so the interior and text stay perfectly crisp while
    /// only the halo bleeding out past this shape's edges is soft.
    private var cardContent: some View {
        VStack(spacing: 6) {
            if clue.isOpened {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.85))
            }
            Text("$\(clue.points)")
                .font(.system(size: 24, weight: .bold, design: .serif))
                .foregroundColor(clue.isOpened ? .white.opacity(0.6) : .jeopardyAccent)
                .strikethrough(clue.isOpened)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(cardFill)
        // Rounder than the original 8pt radius — the board's regular grid of
        // dark cards on a light Parchment background is a textbook setup for
        // the Hermann grid illusion (phantom grey blobs at intersections,
        // driven by retinal ganglion cell lateral inhibition). The effect
        // specifically depends on sharp, aligned right-angle junctions where
        // four cards meet; rounding the corners disrupts that geometry
        // without touching the grid's alignment. Tight density uses a
        // smaller radius since its near-zero gaps already defeat the
        // illusion on their own (see BoardGridDensity.swift) — a big radius
        // there would just look odd with cards nearly touching. See
        // PROJECT.md's "Design system reference" section.
        .cornerRadius(gridDensity.cardCornerRadius)
        // Softer, directional shadow (was `.shadow(radius: 5)`, which is a
        // symmetric black-33%-opacity spread on all sides by default). At
        // every grid intersection, the shadows of diagonally-adjacent cards
        // were overlapping directly on top of each other — real, additive
        // darkening stacked exactly where the illusion also produces a
        // *phantom* dark blob, making it read stronger than the illusion
        // alone would. Lower opacity plus a downward offset (instead of an
        // even spread) means far less shadow reaches into the gap on every
        // side, so adjacent cards' shadows no longer pile up at the corners.
        .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 2)
    }

    /// A very slight gradient rather than a flat fill. Two perfectly
    /// uniform luminance fields meeting at a hard edge is exactly what
    /// maximizes the Hermann grid illusion's retinal response — this
    /// gradient is subtle enough not to read as an intentional design
    /// choice, but it's no longer a perfectly flat field, which softens
    /// that response. See PROJECT.md's "Design system reference" section.
    private var cardFill: LinearGradient {
        if clue.isOpened {
            return LinearGradient(
                colors: [Color.gray.opacity(0.50), Color.gray.opacity(0.60)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [.jeopardyCardHighlight, .jeopardyCard],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func deleteClue() {
        // Clean up any managed video file before removing the clue itself
        MediaStore.deleteVideo(filename: clue.videoFileName)
        modelContext.delete(clue)
    }

    private func reactivateClue() {
        // Reactivating the clue again as if it wasn't answered
        // Prob gonna use this for future ref when I need testing
        clue.isOpened = false
        clue.eliminatedChoiceIndices = []
    }
}