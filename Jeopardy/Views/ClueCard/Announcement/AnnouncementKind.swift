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

    var color: Color {
        switch self {
        case .finalJeopardy: return .yellow
        case .dailyDouble: return .orange
        case .multiplePeople: return .mint
        }
    }
}

struct ClueAnnouncementView: View {
    let kind: AnnouncementKind
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.95), Color.indigo.opacity(0.95)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 26) {
                Image(systemName: kind.symbol)
                    .font(.system(size: 100, weight: .bold))
                    .foregroundColor(kind.color)
                    .shadow(color: kind.color.opacity(0.5), radius: 15)
                Text(kind.title)
                    .font(.system(size: 48, weight: .black, design: .serif))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                Text(kind.message)
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.9))
                Button("Show Clue", action: onContinue)
                    .buttonStyle(.borderedProminent)
                    .tint(kind.color)
                    .controlSize(.large)
            }
            .padding(48)
        }
    }
}
