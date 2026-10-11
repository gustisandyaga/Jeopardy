//
//  ClueCardView.swift
//  Jeopardy
//
//  The visual board tile shown in BoardGridView — one clue's point value and
//  opened/answered state. Purely presentational: navigation, the edit/delete/
//  reactivate actions and their confirmation live in ClueTileView, which wraps
//  this view. Colors for the opened state and the card outline come from the
//  active BoardTheme.
//

import SwiftUI

struct ClueCardView: View {
    @AppStorage(BoardGridDensity.storageKey) private var gridDensityRaw: String = BoardGridDensity.comfortable.rawValue
    @AppStorage(BoardTheme.storageKey) private var boardThemeRaw: String = BoardTheme.parchment.rawValue
    let clue: Clue

    private var gridDensity: BoardGridDensity {
        BoardGridDensity(rawValue: gridDensityRaw) ?? .comfortable
    }

    private var theme: BoardTheme {
        BoardTheme(rawValue: boardThemeRaw) ?? .parchment
    }

    var body: some View {
        ZStack {
            // Soft glow / halo — this card's own gradient, blurred and
            // rendered underneath the sharp card on top. Blur bleeds the
            // filled shape's color past its own edge, so the card-to-
            // backdrop step becomes a short ramp instead of a hard edge.
            // That softens the edge itself (unlike cornerRadius/shadow,
            // which only soften the geometry around it). Comfortable only —
            // in Tight the gaps are already too narrow for a halo to help.
            // See PROJECT.md's "Design system reference" and
            // BoardGridDensity.swift.
            if gridDensity.usesSoftEdge {
                RoundedRectangle(cornerRadius: gridDensity.cardCornerRadius)
                    .fill(cardFill)
                    .blur(radius: 10)
                    .opacity(0.6)
            }

            cardContent
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        // One VoiceOver element per tile: "$400, History, Not opened".
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(clue.points) dollars, \(clue.category)")
        .accessibilityValue(clue.isOpened ? "Opened" : "Not opened")
    }

    /// The sharp, fully-opaque card itself — sits on top of the blurred halo,
    /// so the interior and text stay crisp.
    private var cardContent: some View {
        VStack(spacing: 6) {
            // Opened-state foregrounds come from the theme and are opaque
            // (≥ 6.6:1 on Parchment, ≥ 9.5:1 on Broadcast) — not translucent
            // white on translucent grey, which measured ~1.5:1.
            if clue.isOpened {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 20))
                    .foregroundColor(theme.openedText)
            }
            Text("$\(clue.points)")
                .font(.system(size: 24, weight: .bold, design: .serif))
                .foregroundColor(clue.isOpened ? theme.openedText : .jeopardyAccent)
                .strikethrough(clue.isOpened)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        // Rounded corners break up the sharp aligned right-angle junctions
        // the Hermann grid illusion depends on (Tight uses a smaller radius;
        // its near-zero gaps already defeat the illusion).
        //
        // Fill, outline and shadow live on the background shape (not the
        // whole view), so the shadow doesn't also smear the "$" text.
        // The shadow is soft and directional (low opacity, offset downward)
        // so diagonal neighbours' shadows don't pile up at grid corners.
        .background {
            RoundedRectangle(cornerRadius: gridDensity.cardCornerRadius)
                .fill(cardFill)
                .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 2)
        }
        // Broadcast only: the backdrop is so close to the card color that a
        // thin outline carries the card's boundary (WCAG 1.4.11).
        .overlay {
            if let edge = clue.isOpened ? theme.openedEdge : theme.cardEdge {
                RoundedRectangle(cornerRadius: gridDensity.cardCornerRadius)
                    .strokeBorder(edge, lineWidth: 1)
            }
        }
    }

    /// A very slight gradient rather than a flat fill: two perfectly uniform
    /// fields meeting at a hard edge maximize the Hermann grid response.
    private var cardFill: LinearGradient {
        if clue.isOpened {
            return theme.openedFill
        } else {
            return LinearGradient(
                colors: [.jeopardyCardHighlight, .jeopardyCard],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
