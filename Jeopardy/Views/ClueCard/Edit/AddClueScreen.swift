//
//  AddClueScreen.swift
//  Jeopardy
//
//  Pushed (not modal) screen for creating a brand-new clue or a new Final
//  Jeopardy clue. This is the one deliberate exception to "inline, no
//  separate screen": there is no existing card/screen to expand into when
//  nothing exists yet. It reuses the exact same ClueEditorView used inline
//  by ClueDetailView, so the experience is visually identical even though
//  this specific case is a push rather than an in-place swap.
//
//  Uses the SAME single back-chevron-as-cancel pattern as ClueDetailView:
//  backing out with unsaved (non-blank) fields shows a Save/Discard/Keep
//  Editing dialog rather than silently losing what was typed (#3 User
//  control and freedom). "Dirty" here means "different from a brand-new
//  blank draft" rather than "different from a saved Clue", since there's
//  no existing Clue yet to compare against.
//

import SwiftUI
import SwiftData

struct AddClueScreen: View {
    var isFinalJeopardy: Bool = false

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var existingClues: [Clue]

    @State private var draft = ClueDraft()
    @State private var isShowingDiscardConfirm = false

    private let blankDraft = ClueDraft()

    private var existingCategories: [String] {
        Array(Set(existingClues.map { $0.category })).sorted()
    }

    var body: some View {
        ClueEditorView(
            draft: $draft,
            isFinalJeopardyMode: isFinalJeopardy,
            isNewClue: true,
            existingCategories: existingCategories,
            onSave: save,
            onCancel: requestCancel
        )
        .navigationTitle(isFinalJeopardy ? "New Final Jeopardy Clue" : "New Clue")
        .confirmationDialog(
            "You have unsaved fields for this new clue.",
            isPresented: $isShowingDiscardConfirm,
            titleVisibility: .visible
        ) {
            Button("Save Changes") { save() }
                // Mirrors the toolbar Add button's own `.disabled(...)` in
                // ClueEditorView — previously this path could insert an
                // invalid (e.g. blank Q&A) clue straight into SwiftData
                // because it skipped that check entirely. See PROJECT.md's
                // "Editor Layout, Save Validation, Focus Cleanup, and a
                // Real Edit Button" addendum.
                .disabled(!draft.isValid(isFinalJeopardy: isFinalJeopardy))
            Button("Discard Changes", role: .destructive) { discard() }
            Button("Keep Editing", role: .cancel) {}
        }
    }

    private func save() {
        // Defense in depth: the toolbar Add button and the discard
        // dialog's "Save Changes" button both disable themselves when the
        // draft is invalid, but this guard is what actually stops an
        // invalid clue from ever being inserted, regardless of which path
        // called this — see PROJECT.md's "Editor Layout, Save Validation,
        // Focus Cleanup, and a Real Edit Button" addendum.
        guard draft.isValid(isFinalJeopardy: isFinalJeopardy) else { return }
        let newClue = draft.makeClue(isFinalJeopardy: isFinalJeopardy)
        modelContext.insert(newClue)
        try? modelContext.save()
        dismiss()
    }

    /// (#3) Only interrupts with a confirmation when something was
    /// actually typed/attached — backing out of a still-blank form exits
    /// immediately with no prompt.
    private func requestCancel() {
        if draft != blankDraft {
            isShowingDiscardConfirm = true
        } else {
            dismiss()
        }
    }

    /// Cleans up a freshly-imported video only once "Discard" is the
    /// Host's confirmed choice — never earlier (see ClueEditorView's
    /// cancelTapped() comment for why doing this any sooner is a bug).
    private func discard() {
        if case .video(let filename) = draft.media {
            MediaStore.deleteVideo(filename: filename)
        }
        dismiss()
    }
}
