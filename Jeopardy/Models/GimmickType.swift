//
//  GimmickType.swift
//  Jeopardy
//
//  Created by Gusti Sandyaga Putra Wardhana on 03/09/26.
//


//
//  GimmickType.swift
//  Jeopardy
//
//  A "gimmick" is a game-show style help/power-up a player can use once per
//  game (Phone-a-Friend, 50:50 — more can be added later, e.g. a "trap"
//  that costs the target player points). Each Players row just tracks which
//  gimmick raw values it has already used (see Players.usedGimmicks), so
//  adding a new case here is enough for it to show up everywhere via
//  `allCases` — no other model changes required.
//

import SwiftUI

enum GimmickType: String, CaseIterable, Identifiable, Codable {
    case phoneAFriend
    case fiftyFifty

    var id: String { rawValue }

    var title: String {
        switch self {
        case .phoneAFriend: return "Phone-a-Friend"
        case .fiftyFifty: return "50:50"
        }
    }

    /// Shown in the hover tooltip on that player's icon.
    var description: String {
        switch self {
        case .phoneAFriend:
            return "This player can call a friend outside the app for help. The Host just marks it used here — the actual call happens off-app."
        case .fiftyFifty:
            return "On a multiple-choice clue, removes two incorrect options, leaving the correct answer and one wrong option."
        }
    }

    var icon: String {
        switch self {
        case .phoneAFriend: return "phone.circle.fill"
        case .fiftyFifty: return "scissors.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .phoneAFriend: return .green
        case .fiftyFifty: return .purple
        }
    }
}