//
//  MultipleChoiceEditSection.swift
//  Jeopardy
//
//  Created by Gusti Sandyaga Putra Wardhana on 16/09/26.
//


//
//  MultipleChoiceEditSection.swift
//  Jeopardy
//
//  Lives in Views/ClueCard/Edit/. The "Multiple Choice (Optional)" section
//  of the clue editor — toggle, option fields (2-8), and the correct-
//  answer picker. Split out of ClueEditorView.swift, which also held the
//  layout shell and the media-attach subsystem in the same 688-line file
//  — see PROJECT.md's architecture map. Takes bindings straight into the
//  specific ClueDraft fields it needs, rather than the whole draft, so its
//  interface only exposes what this section actually touches.
//
//  Uses choiceLetter(for:) from Views/ClueCard/Helpers/ChoiceLetter.swift
//  — that helper stays in Helpers/ rather than moving here, since
//  MultipleChoiceOptionsView (the gameplay-side view) also depends on it.
//

import SwiftUI

struct MultipleChoiceEditSection: View {
    @Binding var isMultipleChoice: Bool
    @Binding var choiceOptions: [String]
    @Binding var correctChoiceIndex: Int
    var focusedField: FocusState<ClueEditField?>.Binding
    let isShowingHelp: Bool

    var body: some View {
        SectionContainer(
            title: "Multiple Choice (Optional)",
            help: "Turn this on to give tappable answer options instead of, or alongside, free text. Needs at least 2 filled-in options.",
            isShowingHelp: isShowingHelp
        ) {
            Toggle("Enable multiple choice", isOn: $isMultipleChoice)

            if isMultipleChoice {
                ForEach(choiceOptions.indices, id: \.self) { idx in
                    HStack {
                        Text(choiceLetter(for: idx))
                            .font(.headline)
                            .frame(width: 20)
                        TextField("Option \(choiceLetter(for: idx))", text: $choiceOptions[idx])
                            .focused(focusedField, equals: .choiceOption(idx))
                        if choiceOptions.count > 2 {
                            Button(role: .destructive) { removeOption(at: idx) } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.plain)
                            .help("Remove this option")
                        }
                    }
                }

                Button {
                    choiceOptions.append("")
                } label: {
                    Label("Add Option", systemImage: "plus.circle")
                }
                .disabled(choiceOptions.count >= 8)

                Picker("Correct Answer", selection: $correctChoiceIndex) {
                    ForEach(choiceOptions.indices, id: \.self) { idx in
                        if !choiceOptions[idx].trimmingCharacters(in: .whitespaces).isEmpty {
                            Text(choiceLetter(for: idx)).tag(idx)
                        }
                    }
                }
            }
        }
    }

    private func removeOption(at index: Int) {
        guard choiceOptions.count > 2 else { return }
        choiceOptions.remove(at: index)
        if correctChoiceIndex == index {
            correctChoiceIndex = 0
        } else if correctChoiceIndex > index {
            correctChoiceIndex -= 1
        }
    }
}