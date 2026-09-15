//
//  AddClueScreen.swift
//  Jeopardy
//
//  Created by Gusti Sandyaga Putra Wardhana on 15/09/26.
//


//
//  AddClueScreen.swift
//  Jeopardy
//
//  Pushed (not modal) screen for creating a brand-new clue or a new Final
//  Jeopardy clue. This is the one deliberate exception to "inline, no
//  separate screen": there is no existing card/screen to expand into when
//  nothing exists yet. It reuses the exact same ClueEditorView used inline
//  by ClueDetailView, so the experience is visually identical even though
//  this specific case is a push rather than an in-place swap. See
//  PROJECT.md's "Clue Editor Redesign" addendum for a backlog note about
//  revisiting this with an inline "draft card" pinned to the board later.
//

import SwiftUI
import SwiftData

struct AddClueScreen: View {
    var isFinalJeopardy: Bool = false

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var existingClues: [Clue]

    @State private var draft = ClueDraft()

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
            onCancel: cancel
        )
        .navigationTitle(isFinalJeopardy ? "New Final Jeopardy Clue" : "New Clue")
    }

    private func save() {
        let newClue = draft.makeClue(isFinalJeopardy: isFinalJeopardy)
        modelContext.insert(newClue)
        try? modelContext.save()
        dismiss()
    }

    private func cancel() {
        if case .video(let filename) = draft.media {
            MediaStore.deleteVideo(filename: filename)
        }
        dismiss()
    }
}