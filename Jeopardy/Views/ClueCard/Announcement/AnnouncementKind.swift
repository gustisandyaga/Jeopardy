//
//  AnnouncementKind.swift
//  Jeopardy
//
//  Created by Gusti Sandyaga Putra Wardhana on 21/08/26.
//

import SwiftUI

enum AnnouncementKind {
    case finalJeopardy
    case dailyDouble
    case multiplePeople

    var title: String {
        switch self {
        case .finalJeopardy: return "FINAL JEOPARDY!"
        case .dailyDouble: return "DAILY DOUBLE!"
        case .multiplePeople: return "MULTIPLE PEOPLE!"
        }
    }

    var message: String {
        switch self {
        case .finalJeopardy: return "Set each player's wager in the player bar below, then show the clue."
        case .dailyDouble: return "The selected player may make a wager."
        case .multiplePeople: return "Everyone may answer this clue."
        }
    }

    var symbol: String {
        switch self {
        case .finalJeopardy: return "star.fill"
        case .dailyDouble: return "2.circle.fill"
        case .multiplePeople: return "person.2.fill"
        }
    }

    /// Icon color, drawn on `background` below. Final Jeopardy uses Saffron on
    /// its reserved Indigo Velvet backdrop; Daily Double and Multiple People
    /// use light amber/mint on the board's navy. All measured ≥ 5.6:1 — see
    /// Theme/JeopardyColors.swift and CLAUDE.md.
    var color: Color {
        switch self {
        case .finalJeopardy: return .jeopardyAccent
        case .dailyDouble: return .jeopardyDailyDoubleIcon
        case .multiplePeople: return .jeopardyMultiplePeopleIcon
        }
    }

    /// Opaque backdrop, so the screen no longer depends on the window's
    /// light/dark appearance (the old translucent blue/indigo gradient did,
    /// and the Final Jeopardy icon, itself indigo, nearly vanished into it).
    /// Final Jeopardy keeps its reserved Indigo Velvet as the *background*;
    /// the others use the board's navy. Every icon/text color above is
    /// measured against the lighter stop of its gradient (≥ 5.6:1).
    var background: LinearGradient {
        switch self {
        case .finalJeopardy:
            return LinearGradient(colors: [.jeopardyFinal, .jeopardyFinalDeep],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .dailyDouble, .multiplePeople:
            return LinearGradient(colors: [.jeopardyCardHighlight, .jeopardyCard],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

struct ClueAnnouncementView: View {
    let kind: AnnouncementKind
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            kind.background
                .ignoresSafeArea()

            VStack(spacing: 26) {
                // Glow sits BEHIND the icon, at low opacity. A .shadow on the
                // symbol itself shows through knocked-out glyphs (the "2" in
                // 2.circle.fill) and turned the numeral a murky grey.
                Image(systemName: kind.symbol)
                    .font(.system(size: 100, weight: .bold))
                    .foregroundColor(kind.color)
                    .background {
                        Circle()
                            .fill(kind.color)
                            .blur(radius: 28)
                            .opacity(0.22)
                            .frame(width: 130, height: 130)
                    }
                Text(kind.title)
                    .font(.system(size: 48, weight: .black, design: .serif))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                Text(kind.message)
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.9))
                // Navy label on Saffron (8.7:1). The default prominent
                // button draws a white label, which was 2.2:1 on orange.
                Button(action: onContinue) {
                    Text("Show Clue")
                        .font(.headline)
                        .foregroundColor(.jeopardyCard)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.jeopardyAccent))
                }
                .buttonStyle(.plain)
            }
            .padding(48)
        }
    }
}
