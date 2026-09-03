//
//  GimmickBar.swift
//  Jeopardy
//
//  Created by Gusti Sandyaga Putra Wardhana on 03/09/26.
//


//
//  GimmickBar.swift
//  Jeopardy
//
//  Row of GimmickBadgeViews shown on a player's card. Owns the actual
//  activation logic:
//   - Phone-a-Friend is purely cosmetic — tapping it just marks it used.
//   - 50:50 requires the currently active clue to be multiple choice, not
//     yet revealed, and not already 50:50'd by someone else this clue; it
//     eliminates up to two wrong options directly on the Clue model
//     (shared, so every player sees the result and the lock).
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
                    isEnabled: isEnabled(gimmick),
                    disabledReason: disabledReason(for: gimmick)
                ) {
                    activate(gimmick)
                }
            }
        }
    }

    private func isEnabled(_ gimmick: GimmickType) -> Bool {
        guard !player.hasUsed(gimmick) else { return false }
        return disabledReason(for: gimmick) == nil
    }

    /// nil means "available". Also used to drive the hover tooltip so the
    /// Host understands *why* an icon is greyed out.
    private func disabledReason(for gimmick: GimmickType) -> String? {
        switch gimmick {
        case .phoneAFriend:
            return nil

        case .fiftyFifty:
            guard let activeClue else { return "No active clue" }
            guard activeClue.isMultipleChoice else { return "This clue isn't multiple choice" }
            guard !activeClue.isOpened else { return "Answer already revealed" }
            if activeClue.fiftyFiftyUsed { return "Already used by another player on this clue" }
            if remainingWrongIndices(for: activeClue).isEmpty { return "No options left to eliminate" }
            return nil
        }
    }

    private func remainingWrongIndices(for clue: Clue) -> [Int] {
        let eliminated = Set(clue.eliminatedChoiceIndices)
        return clue.choiceOptions.indices.filter { $0 != clue.correctChoiceIndex && !eliminated.contains($0) }
    }

    private func activate(_ gimmick: GimmickType) {
        guard !player.hasUsed(gimmick) else { return }
        guard disabledReason(for: gimmick) == nil else { return }

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
    /// still visible. Also flips `fiftyFiftyUsed` on the clue itself so no
    /// other player can use 50:50 again on this same clue.
    private func applyFiftyFifty(to clue: Clue) {
        var eliminated = Set(clue.eliminatedChoiceIndices)
        let toEliminate = remainingWrongIndices(for: clue).shuffled().prefix(2)
        eliminated.formUnion(toEliminate)
        clue.eliminatedChoiceIndices = Array(eliminated)
        clue.fiftyFiftyUsed = true
    }
}