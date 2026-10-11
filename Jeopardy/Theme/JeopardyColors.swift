//
//  JeopardyColors.swift
//  Jeopardy
//
//  Centralized theme colors, chosen using the 60-30-10 rule and picked
//  for their color-psychology associations (see PROJECT.md's "Color
//  Theme" addendum for the full reasoning and contrast measurements).
//  Every other view should reference these named constants instead of
//  raw Color.blue / Color.yellow / hex literals, so the palette only
//  ever needs to change in one place.
//
//  - jeopardyBackground (60%) — Parchment. The board grid's backdrop
//                                only (see PROJECT.md — deliberately NOT
//                                applied to the outer window or the clue
//                                detail screen, to preserve system
//                                light/dark mode there).
//  - jeopardyCard        (30%) — Oxford Blue. Standard clue cards and
//                                 category headers; chosen specifically
//                                 for its "knowledge/academia" association
//                                 over a more generic navy.
//  - jeopardyCardHighlight      — A slightly lighter navy, used only as
//                                 the top-left stop of ClueCardView's
//                                 gradient fill (see "Hermann Grid
//                                 Mitigation" addendum in PROJECT.md).
//                                 Never used as a standalone fill color.
//  - jeopardyAccent      (10%) — Saffron. Point values and small
//                                 highlights only — deliberately NOT used
//                                 as a large fill, since bright yellow/gold
//                                 tones read as overpowering at scale.
//  - jeopardyFinal      (reserved) — Indigo Velvet. Final Jeopardy only,
//                                 so that moment reads as a distinct
//                                 "special occasion" rather than another
//                                 blue card.
//
//  Everything below the palette (text/state colors, opened/completed
//  fills, announcement backgrounds) exists because SwiftUI's built-in
//  .green/.yellow/.orange fail contrast on a light window, and because
//  translucent whites over translucent greys can't be measured reliably.
//  Each value here was measured (WCAG 2.x ratio + APCA Lc) before being
//  chosen — see CLAUDE.md's "Color & contrast rules" for the numbers and
//  the method. Re-measure if you change any hex.
//

import SwiftUI
import AppKit

extension Color {
    /// Creates a Color from a 6-digit RGB hex string, with or without a
    /// leading "#". Malformed input falls back to black rather than
    /// crashing.
    init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }

    static let jeopardyBackground = Color(hex: "#F7F5F0")      // Parchment
    static let jeopardyCard = Color(hex: "#002147")            // Oxford Blue
    static let jeopardyCardHighlight = Color(hex: "#123C69")   // Slightly lighter navy — gradient stop only
    static let jeopardyAccent = Color(hex: "#E8B923")          // Saffron
    static let jeopardyFinal = Color(hex: "#4B2E83")           // Indigo Velvet

    /// A color that swaps between two hexes with the system appearance.
    /// Used for text colors on the system window background (which follows
    /// light/dark), as opposed to the board, whose backdrop is fixed.
    static func adaptive(light: String, dark: String) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(Color(hex: isDark ? dark : light))
        })
    }

    // MARK: Text/icon colors on the system window background
    //
    // Light values measured on #FFFFFF and #ECECEC (≥ 5.0:1, Lc ≥ 68);
    // dark values on #2B2B2B (≥ 5.0:1).

    /// Correct answers / "Correct" results. Replaces `.green`, which is 2.2:1 on white.
    static let jeopardyCorrect = adaptive(light: "#14692B", dark: "#5FD97A")
    /// Incorrect results / destructive text. Replaces `.red` (3.6:1 on white).
    static let jeopardyIncorrect = adaptive(light: "#A8201A", dark: "#FF6B63")
    /// Daily Double label, Final Jeopardy star, audio play control.
    /// Replaces `.yellow`, which is 1.5:1 on white.
    static let jeopardyGold = adaptive(light: "#7A5A00", dark: "#FFD60A")
    /// Multiple People label. Replaces `.orange` (2.2:1 on white).
    static let jeopardyAmberText = adaptive(light: "#A04100", dark: "#FF9F0A")

    /// Informational blue (chevrons, tinted info panels, option rows). Replaces `.blue`.
    static let jeopardyInfo = adaptive(light: "#0B5CAD", dark: "#6CB4FF")
    /// Gimmick icon/label colors (Phone-a-Friend, 50:50). Replace `.green`/`.purple`.
    static let jeopardyGimmickCall = jeopardyCorrect
    static let jeopardyGimmickCut = adaptive(light: "#6A3D9A", dark: "#C9A7F0")

    // MARK: Board state fills (board backdrop is fixed Parchment, so these are fixed too)

    /// Opened clue tile: light warm grey, dark slate text (≥ 6.6:1). Kept
    /// well below the navy card's weight so "done" still recedes, and the
    /// small card-vs-backdrop contrast (~1.7:1) is deliberately low — it
    /// also keeps the Hermann grid effect weak for opened tiles.
    static let jeopardyOpenedTop = Color(hex: "#C4C2BB")
    static let jeopardyOpenedBottom = Color(hex: "#BDBBB4")
    static let jeopardyOpenedText = Color(hex: "#2B3340")

    /// Completed category header: dark slate with FULL-opacity white text
    /// (≥ 6.2:1). Distinct from both the navy header and the light opened tile.
    static let jeopardyCompletedTop = Color(hex: "#566173")
    static let jeopardyCompletedBottom = Color(hex: "#4A5463")

    // MARK: Announcement screens (opaque so they don't depend on the window's appearance)

    static let jeopardyFinalDeep = Color(hex: "#2E1A5C")       // Final gradient bottom
    static let jeopardyDailyDoubleIcon = Color(hex: "#FFB84D") // on navy: 6.5–9.3:1
    static let jeopardyMultiplePeopleIcon = Color(hex: "#66D4CF") // on navy: 6.3–9.1:1

    // MARK: Empty-state tile tints (white glyph on top; each ≥ 5.4:1 before the .gradient lift)

    static let jeopardyTileNavy = jeopardyCard
    static let jeopardyTilePurple = Color(hex: "#6A3D9A")
    static let jeopardyTileBurnt = Color(hex: "#A8420A")

    // MARK: Broadcast board theme (see Models/BoardTheme.swift)
    //
    // A near-black navy backdrop like the TV set, so the Oxford Blue cards sit
    // on it at ~1.2:1 instead of 14.7:1 — the Hermann grid illusion scales with
    // that block/street luminance gap. Because the backdrop no longer separates
    // the cards by itself, each card gets a thin lighter outline (3.7:1 vs the
    // backdrop, satisfying WCAG 1.4.11's 3:1 for a component boundary).

    static let jeopardyBroadcastBackdrop = Color(hex: "#000C1D")
    static let jeopardyBroadcastEdge = Color(hex: "#3B6EA5")           // 3.7:1 vs backdrop
    static let jeopardyBroadcastOpenedTop = Color(hex: "#0E2038")
    static let jeopardyBroadcastOpenedBottom = Color(hex: "#0B1B30")
    static let jeopardyBroadcastOpenedEdge = Color(hex: "#3A5778")     // deliberately dimmer: 2.6:1
    static let jeopardyBroadcastOpenedText = Color(hex: "#B8C7DB")     // 9.5–10.1:1 on the opened fill
    static let jeopardyBroadcastCompletedTop = Color(hex: "#3A4659")   // white text 9.5–11.5:1
    static let jeopardyBroadcastCompletedBottom = Color(hex: "#2F3A4C")
    static let jeopardyBroadcastText = Color.white                     // 19.6:1 on backdrop
    static let jeopardyBroadcastSecondaryText = Color(hex: "#A9BBD3")  // 10.0:1 on backdrop
}
