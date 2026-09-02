//
//  Players.swift
//  Jeopardy
//
//  Created by Gusti Sandyaga Putra Wardhana on 30/04/26.
//

import Foundation
import SwiftData

@Model
class Players: Identifiable {
    
    var name: String
    var score: Int = 0
    /// Final Jeopardy is resolved independently for every player. These
    /// values persist while the Host moves between the announcement, clue,
    /// and answer.
    var finalJeopardyWager: Int = 0
    var finalJeopardyResult: String = "unresolved"

    /// Raw values of GimmickType cases this player has already used this
    /// game (e.g. "phoneAFriend", "fiftyFifty"). Stored as strings rather
    /// than an enum array so SwiftData can persist it directly and so new
    /// gimmick cases never require a migration.
    var usedGimmicks: [String] = []

    init(name: String, score: Int) {
        self.name = name
        self.score = score
    }

    func hasUsed(_ gimmick: GimmickType) -> Bool {
        usedGimmicks.contains(gimmick.rawValue)
    }

    func markUsed(_ gimmick: GimmickType) {
        guard !hasUsed(gimmick) else { return }
        usedGimmicks.append(gimmick.rawValue)
    }

    /// Un-marks a gimmick as used, in case the Host taps it by mistake.
    func markUnused(_ gimmick: GimmickType) {
        usedGimmicks.removeAll { $0 == gimmick.rawValue }
    }

    /// Called when starting a fresh game (e.g. alongside "Reset All Scores")
    /// so every player's power-ups are available again.
    func resetGimmicks() {
        usedGimmicks.removeAll()
    }
}
