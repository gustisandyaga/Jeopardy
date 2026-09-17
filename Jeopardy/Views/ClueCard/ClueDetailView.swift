//
//  ClueDetailView.swift
//  Jeopardy
//
//  Created by Gusti Sandyaga Putra Wardhana on 16/09/26.
//


//
//  ClueDetailView.swift
//  Jeopardy
//
//  The full clue screen: announcement (Daily Double / Multiple People /
//  Final Jeopardy) -> question/media/multiple-choice -> reveal answer, plus
//  the inline-edit swap (see ClueEditorView.swift) reached via the "Edit
//  Clue" toolbar button. Split out of the old ClueCard.swift, which also
//  held the board tile, media dispatcher, and multiple-choice gameplay
//  view in the same file — see PROJECT.md's architecture map.
//

import SwiftUI
import SwiftData

struct ClueDetailView: View {
    let clue: Clue
    @Binding var selectedPoints: Int
    @Binding var activeClue: Clue?
    var startInEditMode: Bool = false

    @Environment(\.modelContext) private var modelContext
    @Query private var existingClues: [Clue]

    @State private var showAnswer = false
    @State private var isEditing: Bool
    @State private var editDraft = ClueDraft()
    @State private var editSnapshot = ClueDraft()
    @State private var hasLoadedEditDraft = false
    @State private var isShowingDiscardConfirm = false

    // Shown BEFORE the question/answer for any clue that calls for it
    // (Daily Double, Multiple People Can Answer, or Final Jeopardy). See
    // Clue.needsAnnouncement / ClueAnnouncementView.
    @State private var isShowingAnnouncement: Bool

    init(clue: Clue, selectedPoints: Binding<Int>, activeClue: Binding<Clue?>, startInEditMode: Bool = false) {
        self.clue = clue
        self._selectedPoints = selectedPoints
        self._activeClue = activeClue
        self.startInEditMode = startInEditMode
        self._isEditing = State(initialValue: startInEditMode)
        self._isShowingAnnouncement = State(initialValue: clue.needsAnnouncement && !startInEditMode)
    }

    public var announcementKind: AnnouncementKind? {
        if clue.isFinalJeopardy { return .finalJeopardy }
        if clue.isDailyDouble { return .dailyDouble }
        if clue.isMultiplePeople { return .multiplePeople }
        return nil
    }

    private var existingCategories: [String] {
        Array(Set(existingClues.map { $0.category })).sorted()
    }

    var body: some View {
        Group {
            if isEditing {
                editingContent
            } else if isShowingAnnouncement, let announcementKind {
                ClueAnnouncementView(kind: announcementKind) {
                    withAnimation(.easeInOut) {
                        isShowingAnnouncement = false
                    }
                }
            } else {
                clueContent
            }
        }
        .onAppear {
            activeClue = clue
            if isEditing, !hasLoadedEditDraft {
                editDraft = ClueDraft(from: clue)
                editSnapshot = editDraft
                hasLoadedEditDraft = true
            }
        }
        .onDisappear {
            selectedPoints = 0
            activeClue = nil
        }
    }

    // MARK: - Inline editing (#1, #3, #6, #9, #10 — see ClueEditorView.swift)

    private var editingContent: some View {
        ClueEditorView(
            draft: $editDraft,
            isFinalJeopardyMode: clue.isFinalJeopardy,
            isNewClue: false,
            existingCategories: existingCategories,
            onSave: saveEdits,
            onCancel: requestCancelEdits
        )
        .confirmationDialog(
            "You have unsaved changes to this clue.",
            isPresented: $isShowingDiscardConfirm,
            titleVisibility: .visible
        ) {
            Button("Save Changes") { saveEdits() }
                // Mirrors the toolbar Save button's own `.disabled(...)` in
                // ClueEditorView — previously this path could write an
                // invalid (e.g. blank Q&A) clue straight to SwiftData
                // because it skipped that check entirely. See PROJECT.md's
                // "Unverified / needs confirmation" section.
                .disabled(!editDraft.isValid(isFinalJeopardy: clue.isFinalJeopardy))
            Button("Discard Changes", role: .destructive) { discardEdits() }
            Button("Keep Editing", role: .cancel) {}
        }
    }

    private func startEditing() {
        editDraft = ClueDraft(from: clue)
        editSnapshot = editDraft
        hasLoadedEditDraft = true
        isEditing = true
    }

    /// (#3 User control and freedom) — only interrupts with a confirmation
    /// when the draft actually differs from what editing started with.
    private func requestCancelEdits() {
        if editDraft != editSnapshot {
            isShowingDiscardConfirm = true
        } else {
            isEditing = false
        }
    }

    private func discardEdits() {
        if case .video(let filename) = editDraft.media, filename != clue.videoFileName {
            MediaStore.deleteVideo(filename: filename)
        }
        isEditing = false
    }

    private func saveEdits() {
        // Defense in depth: the toolbar Save button and the discard
        // dialog's "Save Changes" button both disable themselves when the
        // draft is invalid, but this guard is what actually stops an
        // invalid clue from ever reaching SwiftData, regardless of which
        // path called this — see PROJECT.md's "Unverified / needs
        // confirmation" section.
        guard editDraft.isValid(isFinalJeopardy: clue.isFinalJeopardy) else { return }
        editDraft.apply(to: clue, isFinalJeopardy: clue.isFinalJeopardy)
        try? modelContext.save()
        isEditing = false
    }

    // MARK: - Read-only clue display (unchanged from before)

    private var clueContent: some View {
        VStack(spacing: 20) {
            HStack {
                Text(clue.category.uppercased()).font(.headline).foregroundColor(.secondary)
                if clue.isDailyDouble {
                    Label("Daily Double", systemImage: "2.circle.fill")
                        .font(.caption.bold())
                        .foregroundColor(.yellow)
                } else if clue.isMultiplePeople {
                    Label("Multiple People", systemImage: "person.2.fill")
                        .font(.caption.bold())
                        .foregroundColor(.orange)
                }
                Spacer()
            }

            if clue.isDailyDouble || clue.isFinalJeopardy {
                Text(clue.isFinalJeopardy
                     ? "Set each player's wager in the player bar below, then mark each result after revealing the answer."
                     : "Remember to lock in the wager — right-click a player below and choose \u{201C}Adjust Score (Wager)\u{2026}\u{201D}.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            ClueMediaView(clue: clue)

            Text(clue.question)
                .font(.system(size: 32, weight: .bold, design: .serif))
                .multilineTextAlignment(.center)

            if clue.isMultipleChoice {
                MultipleChoiceOptionsView(clue: clue, showAnswer: showAnswer) {
                    revealAnswer()
                }
            }

            if showAnswer {
                VStack(spacing: 12) {
                    if let answerImageData = clue.answerImageData {
                        ExpandingClueImageView(imageData: answerImageData, maxWidth: 500, maxHeight: 320)
                    }
                    if !clue.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(clue.answer)
                            .font(.title).foregroundColor(.green)
                            .multilineTextAlignment(.center)
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Spacer()

            Button(showAnswer ? "Hide Answer" : "Reveal Answer") {
                if showAnswer {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showAnswer = false
                    }
                } else {
                    revealAnswer()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        // Moved from a small inline icon-only button next to the category
        // label to a proper toolbar item — matches ContentView's "Add
        // Clue"/"Save Board"/"Reset Board" styling (Label with text + SF
        // Symbol) for consistency (Nielsen #4), and gives the Host a much
        // larger, easier-to-hit target (Fitts's Law) than the old
        // icon-only `Image(systemName: "pencil.circle")`.
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: startEditing) {
                    Label("Edit Clue", systemImage: "pencil.circle.fill")
                }
                .help("Edit this clue")
            }
        }
    }

    private func revealAnswer() {
        guard !showAnswer else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            showAnswer = true
            SoundManager.instance.playSound(named: "reveal_ding")
            clue.isOpened = true
        }
    }
}