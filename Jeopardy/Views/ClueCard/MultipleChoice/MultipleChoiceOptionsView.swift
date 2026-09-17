//
//  MultipleChoiceOptionsView.swift
//  Jeopardy
//
//  Created by Gusti Sandyaga Putra Wardhana on 16/09/26.
//


//
//  MultipleChoiceOptionsView.swift
//  Jeopardy
//
//  Lives in Views/ClueCard/MultipleChoice/. Renders clue.choiceOptions as
//  tappable rows. Before the answer is revealed, tapping a wrong option
//  crosses it out (representing "a player guessed this and got it
//  wrong"); tapping the correct option jumps straight to reveal, same as
//  pressing "Reveal Answer". Once revealed, the correct row turns green
//  and everything else is dimmed/struck as appropriate. The 50:50 gimmick
//  eliminates options the same way, just from GimmickBar instead of a tap
//  here. Split out of the old ClueCard.swift — see PROJECT.md's
//  architecture map.
//
//  Uses choiceLetter(for:) from Views/ClueCard/Helpers/ChoiceLetter.swift
//  — that helper stays in Helpers/ rather than moving here, since
//  ClueEditorView (a different feature) also depends on it; see the
//  reasoning in that file.
//

import SwiftUI

struct MultipleChoiceOptionsView: View {
    let clue: Clue
    let showAnswer: Bool
    let onCorrectSelected: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(clue.choiceOptions.enumerated()), id: \.offset) { index, option in
                optionRow(index: index, option: option)
            }
        }
        .frame(maxWidth: 480)
    }

    private func optionRow(index: Int, option: String) -> some View {
        let isEliminated = clue.eliminatedChoiceIndices.contains(index)
        let isCorrect = index == clue.correctChoiceIndex
        let letter = choiceLetter(for: index)

        return Button {
            guard !showAnswer else { return }
            if isCorrect {
                onCorrectSelected()
            } else {
                toggleElimination(index)
            }
        } label: {
            HStack {
                Text(letter)
                    .font(.headline)
                    .frame(width: 24)
                Text(option)
                    .strikethrough(isEliminated && !(showAnswer && isCorrect))
                    .multilineTextAlignment(.leading)
                Spacer()
                if showAnswer && isCorrect {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(rowBackground(isEliminated: isEliminated, isCorrect: isCorrect))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(showAnswer && isCorrect ? Color.green.opacity(0.6) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(showAnswer || isEliminated)
        .foregroundColor(.primary)
    }

    private func rowBackground(isEliminated: Bool, isCorrect: Bool) -> Color {
        if showAnswer && isCorrect { return Color.green.opacity(0.22) }
        if isEliminated { return Color.gray.opacity(0.12) }
        return Color.blue.opacity(0.08)
    }

    private func toggleElimination(_ index: Int) {
        if let pos = clue.eliminatedChoiceIndices.firstIndex(of: index) {
            clue.eliminatedChoiceIndices.remove(at: pos)
        } else {
            clue.eliminatedChoiceIndices.append(index)
        }
    }
}