//
//  ChoiceLetter.swift
//  Jeopardy
//
//  Small shared helper so multiple-choice option letters (A, B, C...) are
//  computed the same way everywhere a variable-length `Clue.choiceOptions`
//  list is rendered — the form (ClueFormView) and the live clue view
//  (MultipleChoiceOptionsView) both use this instead of a fixed A–D array,
//  since choices are no longer capped at 4.
//

import Foundation

/// Converts a 0-based option index into a display letter ("A", "B", ...
/// "Z"), falling back to a 1-based number past that so an unreasonably long
/// list still renders something sane instead of crashing.
func choiceLetter(for index: Int) -> String {
    guard index >= 0, index < 26, let scalar = UnicodeScalar(65 + index) else {
        return "\(index + 1)"
    }
    return String(Character(scalar))
}
