//
//  BoardGridDensity.swift
//  Jeopardy
//
//  Created by Gusti Sandyaga Putra Wardhana on 14/09/26.
//


//
//  BoardGridDensity.swift
//  Jeopardy
//
//  A user-facing accessibility preference for how tightly clue cards and
//  category headers are packed on the board.
//
//  - .comfortable — the default. Moderate gaps between cards, softened
//                    with a blurred edge halo (see ClueCard.swift /
//                    PROJECT.md's "Hermann Grid Mitigation" addendum) to
//                    reduce the Hermann grid illusion some people see at
//                    the board's regular intersections.
//  - .tight        — removes the gaps almost entirely instead. This
//                    independently defeats the same illusion by removing
//                    the "streets" the phantom intersections form on —
//                    the same principle behind why a reference board with
//                    a very tightly-packed layout showed none of the
//                    effect at all, without needing any blur.
//
//  Persisted via @AppStorage(BoardGridDensity.storageKey) so it's
//  remembered across launches. Both BoardGridView and ClueCardView read
//  it directly (rather than threading a binding down through init), and
//  ContentView's toolbar is what lets the Host switch it live.
//

import SwiftUI

enum BoardGridDensity: String, CaseIterable, Identifiable {
    case comfortable
    case tight

    static let storageKey = "boardGridDensity"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .comfortable: return "Comfortable"
        case .tight: return "Tight"
        }
    }

    var subtitle: String {
        switch self {
        case .comfortable: return "Moderate spacing with a softened edge"
        case .tight: return "Minimal gaps between cards"
        }
    }

    var icon: String {
        switch self {
        case .comfortable: return "square.grid.3x3.middle.filled"
        case .tight: return "square.grid.3x3.fill"
        }
    }

    /// Gap between category columns (BoardGridView's `columnSpacing`).
    var columnSpacing: CGFloat {
        switch self {
        case .comfortable: return 20
        case .tight: return 3
        }
    }

    /// Gap between clue cards within a single category column
    /// (BoardGridView's per-column `VStack` spacing).
    var rowSpacing: CGFloat {
        switch self {
        case .comfortable: return 15
        case .tight: return 3
        }
    }

    /// Used by both ClueCardView and CategoryHeader. Tight uses a smaller
    /// radius — with cards nearly touching, a large radius would look odd
    /// rather than purposeful.
    var cardCornerRadius: CGFloat {
        switch self {
        case .comfortable: return 16
        case .tight: return 6
        }
    }

    /// Whether the blurred edge halo (see ClueCard.swift) should render.
    /// Off in Tight — gaps are already narrow enough that a blurred halo
    /// would just muddy adjacent cards together rather than help.
    var usesSoftEdge: Bool {
        self == .comfortable
    }
}