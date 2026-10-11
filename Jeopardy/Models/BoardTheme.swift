//
//  BoardTheme.swift
//  Jeopardy
//
//  Which backdrop the board grid sits on. A user-facing accessibility
//  preference, sibling of BoardGridDensity.
//
//  - .parchment — the original light backdrop. High card/backdrop contrast
//                 (14.7:1), so the Hermann grid illusion is at its strongest
//                 in Comfortable density; Tight density is its main fix.
//  - .broadcast — a near-black navy backdrop like the TV set. Card/backdrop
//                 contrast drops to ~1.2:1, which weakens the illusion
//                 itself; cards get a thin outline so they stay visibly
//                 separate (WCAG 1.4.11). Opened tiles recede into the dark
//                 instead of turning into bright grey blocks.
//
//  Everything that varies with the theme lives here, so views ask the theme
//  rather than branching on it. Persisted via @AppStorage(BoardTheme.storageKey).
//

import SwiftUI

enum BoardTheme: String, CaseIterable, Identifiable {
    case parchment
    case broadcast

    static let storageKey = "boardTheme"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .parchment: return "Parchment"
        case .broadcast: return "Broadcast"
        }
    }

    var subtitle: String {
        switch self {
        case .parchment: return "Light backdrop"
        case .broadcast: return "Dark backdrop, like the TV set — weakest grid illusion"
        }
    }

    var icon: String {
        switch self {
        case .parchment: return "sun.max"
        case .broadcast: return "tv"
        }
    }

    var backdrop: Color {
        switch self {
        case .parchment: return .jeopardyBackground
        case .broadcast: return .jeopardyBroadcastBackdrop
        }
    }

    /// Text/icons drawn directly on the backdrop (e.g. the empty state).
    var primaryText: Color {
        switch self {
        case .parchment: return .black
        case .broadcast: return .jeopardyBroadcastText
        }
    }

    var secondaryText: Color {
        switch self {
        case .parchment: return Color.black.opacity(0.65)
        case .broadcast: return .jeopardyBroadcastSecondaryText
        }
    }

    /// Outline on active cards/headers. nil in Parchment, where the
    /// backdrop contrast already defines the edge.
    var cardEdge: Color? {
        switch self {
        case .parchment: return nil
        case .broadcast: return .jeopardyBroadcastEdge
        }
    }

    // MARK: Opened clue tile

    var openedFill: LinearGradient {
        let colors: [Color]
        switch self {
        case .parchment: colors = [.jeopardyOpenedTop, .jeopardyOpenedBottom]
        case .broadcast: colors = [.jeopardyBroadcastOpenedTop, .jeopardyBroadcastOpenedBottom]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var openedText: Color {
        switch self {
        case .parchment: return .jeopardyOpenedText
        case .broadcast: return .jeopardyBroadcastOpenedText
        }
    }

    var openedEdge: Color? {
        switch self {
        case .parchment: return nil
        case .broadcast: return .jeopardyBroadcastOpenedEdge
        }
    }

    // MARK: Completed category header

    var completedFill: LinearGradient {
        let colors: [Color]
        switch self {
        case .parchment: colors = [.jeopardyCompletedTop, .jeopardyCompletedBottom]
        case .broadcast: colors = [.jeopardyBroadcastCompletedTop, .jeopardyBroadcastCompletedBottom]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
