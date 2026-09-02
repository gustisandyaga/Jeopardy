//
//  GimmickBar.swift
//  Jeopardy
//
//  Created by Gusti Sandyaga Putra Wardhana on 02/09/26.
//


//
//  GimmickBar.swift
//  Jeopardy
//
//  Row of GimmickBadgeViews shown on a player's card. Owns the actual
//  activation logic:
//   - Phone-a-Friend is purely cosmetic — tapping it just marks it used.
//   - 50:50 requires the currently active clue to be multiple choice and
//     not yet revealed; it eliminates up to two wrong options directly on
//     the Clue model (shared, so every player sees the result).
//

import SwiftUI
import SwiftData

struct GimmickBar: View {
    let player: Players
    let activeClue: Clue?
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        HStack(spacing: 6) {
            ForEach(GimmickType.allCases) { gimmick in
                GimmickBadgeView(
                    gimmick: gimmick,
                    isUsed: player.hasUsed(gimmick),
                    isEnabled: isEnabled(gimmick)
                ) {
                    activate(gimmick)
                }
            }
        }
    }

    private func isEnabled(_ gimmick: GimmickType) -> Bool {
        guard !player.hasUsed(gimmick) else { return false }
        switch gimmick {
        case .phoneAFriend:
            return true
        case .fiftyFifty:
            guard let activeClue, activeClue.isMultipleChoice, !activeClue.isOpened else { return false }
            return remainingWrongIndices(for: activeClue).count > 0
        }
    }

    private func remainingWrongIndices(for clue: Clue) -> [Int] {
        let eliminated = Set(clue.eliminatedChoiceIndices)
        return clue.choiceOptions.indices.filter { $0 != clue.correctChoiceIndex && !eliminated.contains($0) }
    }

    private func activate(_ gimmick: GimmickType) {
        guard !player.hasUsed(gimmick) else { return }

        switch gimmick {
        case .phoneAFriend:
            player.markUsed(gimmick)

        case .fiftyFifty:
            guard let activeClue else { return }
            applyFiftyFifty(to: activeClue)
            player.markUsed(gimmick)
        }

        try? modelContext.save()
    }

    /// Eliminates up to two wrong options, leaving the correct answer and
    /// (if there were originally 3+ wrong options) exactly one wrong option
    /// still visible.
    private func applyFiftyFifty(to clue: Clue) {
        var eliminated = Set(clue.eliminatedChoiceIndices)
        let toEliminate = remainingWrongIndices(for: clue).shuffled().prefix(2)
        eliminated.formUnion(toEliminate)
        clue.eliminatedChoiceIndices = Array(eliminated)
    }
}