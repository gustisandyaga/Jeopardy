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
//  - jeopardyAccent      (10%) — Saffron. Point values and small
//                                 highlights only — deliberately NOT used
//                                 as a large fill, since bright yellow/gold
//                                 tones read as overpowering at scale.
//  - jeopardyFinal      (reserved) — Indigo Velvet. Final Jeopardy only,
//                                 so that moment reads as a distinct
//                                 "special occasion" rather than another
//                                 blue card.
//

import SwiftUI

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

    static let jeopardyBackground = Color(hex: "#F7F5F0") // Parchment
    static let jeopardyCard = Color(hex: "#002147")       // Oxford Blue
    static let jeopardyAccent = Color(hex: "#E8B923")     // Saffron
    static let jeopardyFinal = Color(hex: "#4B2E83")      // Indigo Velvet
}
