//
//  ClueEditorView.swift
//  Jeopardy
//
//  The shared editing surface used both inline inside ClueDetailView (when
//  editing an existing clue) and by AddClueScreen (when creating a new
//  one). Operates purely on a ClueDraft binding — the caller decides what
//  Save/Cancel actually do (write to a live Clue vs. insert a new one).
//
//  This file is the layout shell only: adaptive two/one-column layout,
//  status banner, toolbar, undo/save/cancel, and the General Info / Clue
//  Type / Question&Answer sections. The media-attach subsystem and the
//  Multiple Choice section used to live in this same 688-line file — they
//  now live in MediaAttachmentSection.swift and
//  MultipleChoiceEditSection.swift respectively, each with a narrower
//  interface into just the ClueDraft fields they touch. See PROJECT.md's
//  architecture map.
//
//  Heuristic notes (see PROJECT.md's "Key data-model decisions" /
//  "Design system reference" sections for the fuller write-up):
//   - #1 Visibility of system status  -> statusBanner (mode + Cmd+S hint)
//   - #3 User control and freedom     -> Cmd+Z undo stack; the back
//                                         chevron (NOT a separate Cancel
//                                         button) routes through the
//                                         caller's discard/save
//                                         confirmation when dirty
//   - #6 Recognition rather than recall -> reused by ClueDetailView in place
//   - #10 Help and documentation      -> per-section captions toggled by
//                                         the "?" toolbar button
//   - Gestalt common region/proximity -> SectionContainer gives each
//                                         conceptual group its own visible
//                                         boundary instead of relying on
//                                         whitespace alone; the body is
//                                         further split into a "setup"
//                                         column and a "content" column
//                                         (see body / setupColumn /
//                                         contentColumn below) so related
//                                         sections sit next to each other
//                                         instead of every section
//                                         stretching the full window width
//   - WCAG 1.4.10 Reflow              -> the 2-column split only applies
//                                         when there's room for it
//                                         (checked against proxy.size.width);
//                                         narrow windows fall back to the
//                                         original single column instead
//                                         of clipping
//   - WCAG-adjacent (click-away)      -> tapping empty space drops focus,
//                                         same pattern as PlayerView's
//                                         name field
//

import SwiftUI
import SwiftData

struct ClueEditorView: View {
    @Binding var draft: ClueDraft
    let isFinalJeopardyMode: Bool
    let isNewClue: Bool
    let existingCategories: [String]
    let onSave: () -> Void
    /// Called when the Host backs out. The caller (ClueDetailView /
    /// AddClueScreen) owns the actual dirty-check + confirmation dialog —
    /// this view never deletes anything on the Host's behalf before that
    /// decision is made (see cancelTapped()).
    let onCancel: () -> Void

    @FocusState private var focusedField: ClueEditField?
    @State private var isShowingHelp = false

    @State private var undoStack: [ClueDraft] = []
    @State private var isApplyingUndo = false

    private let pointOptions = [200, 400, 600, 800, 1000]

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    statusBanner

                    // Adaptive 2-column layout: try the wide 2-column split
                    // first, fall back to the original single-column stack
                    // when the available width can't fit both columns at
                    // their minimum width. See setupColumn/contentColumn below
                    // for the actual grouping.

                    if proxy.size.width >= 700 {
                        twoColumnLayout
                    } else {
                        singleColumnLayout
                    }

                }
                .padding(24)
                // (#3 / click-away-to-unfocus) Tapping any non-interactive area
                // drops keyboard focus — same pattern PlayerView already uses
                // for its name field. Buttons/fields still consume their own
                // taps normally; this only catches taps that land on empty
                // space between them.
                .contentShape(Rectangle())
                .onTapGesture { focusedField = nil }
            }
        }
        .frame(minWidth: 480, minHeight: 560)
        .onChange(of: draft) { oldValue, _ in
            guard !isApplyingUndo else { return }
            undoStack.append(oldValue)
            if undoStack.count > 50 { undoStack.removeFirst() }
        }
        .background(
            Group {
                Button("Undo") { undo() }
                    .keyboardShortcut("z", modifiers: .command)
                Button(isNewClue ? "Add" : "Save") { save() }
                    .keyboardShortcut("s", modifiers: .command)
            }
            .hidden()
        )
        // NOTE: hides the system-provided back chevron so the single
        // custom one below (.navigation placement) is the only back/cancel
        // affordance — see file header. This modifier's cross-platform
        // behavior on a macOS-hosted NavigationStack hasn't been confirmed
        // in a real Xcode build; verify the native chevron is actually
        // gone (not just visually duplicated) before relying on this. See
        // PROJECT.md's "Unverified / needs confirmation" section.
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    cancelTapped()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("Back")
                .help(isNewClue ? "Discard this new clue" : "Back (will ask before discarding unsaved changes)")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isNewClue ? "Add" : "Save") { save() }
                    .disabled(!draft.isValid(isFinalJeopardy: isFinalJeopardyMode))
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    isShowingHelp.toggle()
                } label: {
                    Image(systemName: isShowingHelp ? "questionmark.circle.fill" : "questionmark.circle")
                }
                .help("Show or hide a plain-language explanation of each section")
            }
        }
    }

    // MARK: - Adaptive layout (2-column setup/content split)

    /// "Setup" — how this clue behaves: category/points/type, plus
    /// Multiple Choice (still a configuration decision, even though its
    /// option list can grow long).
    private var setupColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !isFinalJeopardyMode {
                generalSection
                typeSection
            } else {
                SectionContainer(
                    title: "Final Jeopardy",
                    help: "This clue plays as an optional bonus round below the main board. It has no category or point value on the grid.",
                    isShowingHelp: isShowingHelp
                ) {
                    EmptyView()
                }
            }
            MultipleChoiceEditSection(
                isMultipleChoice: $draft.isMultipleChoice,
                choiceOptions: $draft.choiceOptions,
                correctChoiceIndex: $draft.correctChoiceIndex,
                focusedField: $focusedField,
                isShowingHelp: isShowingHelp
            )
        }
    }

    /// "Content" — what this clue actually shows/asks: the attached media
    /// and the question/answer text itself.
    private var contentColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            MediaAttachmentSection(
                media: $draft.media,
                answerImageData: $draft.answerImageData,
                isShowingHelp: isShowingHelp
            )
            questionAnswerSection
        }
    }

    /// Preferred layout when there's enough width: setup on the left,
    /// content on the right, each with a sane minimum before either
    /// column gets uncomfortably cramped.
    private var twoColumnLayout: some View {
        HStack(alignment: .top, spacing: 20) {
            setupColumn.frame(minWidth: 340, maxWidth: .infinity, alignment: .top)
            contentColumn.frame(minWidth: 340, maxWidth: .infinity, alignment: .top)
        }
    }

    /// Fallback for narrow widths (resized macOS window, iPhone/iPad
    /// portrait) — the original stacked order, so nothing clips or
    /// requires horizontal scrolling (WCAG 1.4.10 Reflow).
    private var singleColumnLayout: some View {
        VStack(alignment: .leading, spacing: 16) {
            setupColumn
            contentColumn
        }
    }

    // MARK: - Status banner (#1 Visibility of system status)

    private var statusBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: isNewClue ? "plus.circle.fill" : "pencil.circle.fill")
            VStack(alignment: .leading, spacing: 2) {
                Text(isNewClue ? "Creating New Clue" : "Editing Clue")
                    .font(.headline)
                Text("Press ⌘S to save")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(Color.accentColor.opacity(0.15))
        .cornerRadius(8)
    }

    // MARK: - General info

    private var generalSection: some View {
        SectionContainer(
            title: "General Info",
            help: "The category groups this clue into a column on the board. Points is what it's worth when answered correctly.",
            isShowingHelp: isShowingHelp
        ) {
            TextField("Category", text: $draft.category)
                .focused($focusedField, equals: .category)
                .textInputSuggestions {
                    ForEach(existingCategories, id: \.self) { cat in
                        Text(cat).textInputCompletion(cat)
                    }
                }

            Picker("Points", selection: pointsBinding) {
                ForEach(pointOptions, id: \.self) { value in
                    Text("$\(value)").tag(value)
                }
                Text("Custom…").tag(-1)
            }

            if draft.isCustomPoints {
                TextField("Custom amount", text: $draft.customPointsText)
                    .focused($focusedField, equals: .customPoints)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
            }
        }
    }

    private var pointsBinding: Binding<Int> {
        Binding(
            get: { draft.isCustomPoints ? -1 : draft.points },
            set: { newValue in
                if newValue == -1 {
                    draft.isCustomPoints = true
                } else {
                    draft.isCustomPoints = false
                    draft.points = newValue
                }
            }
        )
    }

    // MARK: - Clue type

    private var typeSection: some View {
        SectionContainer(
            title: "Clue Type",
            help: "Daily Double and Multiple People show a full-screen announcement before this clue is revealed. Multiple Choice is set up separately below and can be combined with either.",
            isShowingHelp: isShowingHelp
        ) {
            Picker("Type", selection: $draft.kind) {
                ForEach(ClueKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Question / Answer

    private var questionAnswerSection: some View {
        SectionContainer(
            title: "Clue Details",
            help: "The Question is what the Host reads aloud; the Answer (or multiple-choice options above) is what's revealed after.",
            isShowingHelp: isShowingHelp
        ) {
            MultilineClueField(title: "Question", text: $draft.question, focus: $focusedField, field: .question)
            MultilineClueField(
                title: draft.hasValidMultipleChoiceAnswer ? "Answer (optional — multiple choice is set)" : "Answer",
                text: $draft.answer,
                focus: $focusedField,
                field: .answer
            )
        }
    }

    // MARK: - Undo / Save / Cancel

    private func undo() {
        guard let previous = undoStack.popLast() else { return }
        isApplyingUndo = true
        draft = previous
        isApplyingUndo = false
    }

    private func save() {
        focusedField = nil
        guard draft.isValid(isFinalJeopardy: isFinalJeopardyMode) else { return }
        onSave()
    }

    /// Fires from the single back-chevron button. Deliberately does NOT
    /// delete anything here — the caller's onCancel decides whether this
    /// is a clean exit or needs a Save/Discard/Keep Editing prompt first,
    /// and any video cleanup only happens once "Discard" is the Host's
    /// actual, confirmed choice (see ClueDetailView.discardEdits /
    /// AddClueScreen's discard path). Deleting the file before that
    /// decision was a real bug in a previous version: if the Host had
    /// picked "Save Changes" from the resulting dialog, the video would
    /// already be gone from disk by the time save ran.
    private func cancelTapped() {
        onCancel()
    }
}

/// `TextEditor` deliberately accepts return/newline input, unlike a plain
/// `TextField`, so multi-line lists and multiple-choice-style answers can
/// still be typed into a free-text Question/Answer.
private struct MultilineClueField: View {
    let title: String
    @Binding var text: String
    var focus: FocusState<ClueEditField?>.Binding
    var field: ClueEditField

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline)
            TextEditor(text: $text)
                .focused(focus, equals: field)
                .font(.body)
                .frame(minHeight: 110)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.25), lineWidth: 1))
        }
        .padding(.vertical, 2)
    }
}
