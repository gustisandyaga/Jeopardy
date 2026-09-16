//
//  MediaAttachment.swift
//  Jeopardy
//
//  Created by Gusti Sandyaga Putra Wardhana on 15/09/26.
//


//
//  ClueDraft.swift
//  Jeopardy
//
//  Plain (non-SwiftData) value type mirroring every editable field on
//  `Clue`. `ClueEditorView` operates entirely on a `ClueDraft` binding —
//  never touching a live `Clue`/`ModelContext` directly — so editing can
//  be freely undone (Cmd+Z, via snapshot comparison) or discarded without
//  ever having written anything to the database until the Host explicitly
//  saves. This also makes "does the Host have unsaved changes?" a single
//  `draft != snapshot` comparison instead of tracking ~15 separate fields
//  by hand.
//

import Foundation

/// Exactly one attached medium, or none. Replaces three independent
/// optionals (imageData/audioData/videoFileName) that could previously, in
/// principle, drift out of the "pick at most one" rule if a future change
/// forgot to clear the other two — this makes that invariant part of the
/// type itself rather than a convention enforced by hand at every call site.
enum MediaAttachment: Equatable {
    case none
    case image(Data)
    case audio(Data)
    /// `filename` is a MediaStore-managed filename, same meaning as
    /// `Clue.videoFileName`.
    case video(filename: String)

    var isNone: Bool { self == .none }
}

/// Mutually-exclusive announcement type. Multiple Choice is deliberately
/// NOT a case here — it stays the independent bool it already was on
/// `Clue`, since a clue can be e.g. Daily Double *and* multiple choice.
enum ClueKind: String, CaseIterable, Identifiable, Equatable {
    case standard
    case dailyDouble
    case multiplePeople

    var id: Self { self }

    var title: String {
        switch self {
        case .standard: return "Standard"
        case .dailyDouble: return "Daily Double"
        case .multiplePeople: return "Multiple People"
        }
    }
}

/// Fields that can hold keyboard focus in `ClueEditorView`. This used to
/// also cover non-text controls (Picker/Toggle/Button) in an attempt to
/// give the editor a full custom Tab order across every control, not just
/// text fields — see `PROJECT.md`'s "Clue Editor Redesign — refinements"
/// addendum. That was tested and confirmed to not work: macOS gates Tab
/// traversal for non-text controls behind the user's system-level "Full
/// Keyboard Access" preference, which an app can't override, so those
/// extra cases and their `.focused()` bindings did nothing and were
/// removed. What's left is just the real text-entry fields, kept so
/// click-away-to-unfocus (tapping empty space in the editor) still has
/// something to null out.
enum ClueEditField: Hashable {
    case category
    case customPoints
    case choiceOption(Int)
    case question
    case answer
}

struct ClueDraft: Equatable {
    var category: String = ""
    var points: Int = 200
    var isCustomPoints: Bool = false
    var customPointsText: String = ""

    var kind: ClueKind = .standard

    var media: MediaAttachment = .none
    /// Only meaningful alongside `.image` media — same role as
    /// `Clue.answerImageData` today (an optional uncropped original shown
    /// only at reveal time).
    var answerImageData: Data?

    var question: String = ""
    var answer: String = ""

    var isMultipleChoice: Bool = false
    var choiceOptions: [String] = ["", ""]
    var correctChoiceIndex: Int = 0

    var effectivePoints: Int {
        isCustomPoints ? (Int(customPointsText.trimmingCharacters(in: .whitespaces)) ?? 0) : points
    }

    /// Non-empty options (trimmed) plus the correct index remapped into
    /// that filtered list — identical logic to the old
    /// `ClueFormView.buildChoiceOptions()`, just living on the draft now.
    func builtChoiceOptions() -> (options: [String], correctIndex: Int)? {
        let trimmed = choiceOptions.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let nonEmpty = trimmed.enumerated().filter { !$0.element.isEmpty }
        guard nonEmpty.count >= 2 else { return nil }
        guard let newIndex = nonEmpty.firstIndex(where: { $0.offset == correctChoiceIndex }) else { return nil }
        return (nonEmpty.map { $0.element }, newIndex)
    }

    var hasValidMultipleChoiceAnswer: Bool {
        isMultipleChoice && builtChoiceOptions() != nil
    }

    func isValid(isFinalJeopardy: Bool) -> Bool {
        let questionOK = !question.trimmingCharacters(in: .whitespaces).isEmpty
        let answerOK = !answer.trimmingCharacters(in: .whitespaces).isEmpty || hasValidMultipleChoiceAnswer
        if isFinalJeopardy { return questionOK && answerOK }
        let categoryOK = !category.trimmingCharacters(in: .whitespaces).isEmpty
        return categoryOK && questionOK && answerOK && effectivePoints > 0
    }

    // MARK: - Conversion

    init() {}

    /// Builds a draft that mirrors an existing clue's current values —
    /// the inline-editing equivalent of the old
    /// `ClueFormView.populateFieldsIfNeeded()`.
    init(from clue: Clue) {
        category = clue.category
        points = clue.points
        if [200, 400, 600, 800, 1000].contains(clue.points) {
            isCustomPoints = false
        } else {
            isCustomPoints = true
            customPointsText = String(clue.points)
        }

        if clue.isDailyDouble {
            kind = .dailyDouble
        } else if clue.isMultiplePeople {
            kind = .multiplePeople
        } else {
            kind = .standard
        }

        if let imageData = clue.imageData {
            media = .image(imageData)
        } else if let filename = clue.videoFileName {
            media = .video(filename: filename)
        } else if let audioData = clue.audioData {
            media = .audio(audioData)
        } else {
            media = .none
        }
        answerImageData = clue.answerImageData

        question = clue.question
        answer = clue.answer

        isMultipleChoice = clue.isMultipleChoice
        if clue.isMultipleChoice, !clue.choiceOptions.isEmpty {
            choiceOptions = clue.choiceOptions
            correctChoiceIndex = min(max(clue.correctChoiceIndex, 0), choiceOptions.count - 1)
        } else {
            choiceOptions = ["", ""]
            correctChoiceIndex = 0
        }
    }

    /// Applies this draft onto a live `Clue`, matching the field-by-field
    /// assignment the old `ClueFormView.saveClue()` performed — including
    /// resetting playthrough-only state (`eliminatedChoiceIndices`,
    /// `fiftyFiftyUsed`) since editing options can shift indices.
    func apply(to clue: Clue, isFinalJeopardy: Bool) {
        clue.category = isFinalJeopardy ? "Final Jeopardy" : category
        clue.points = isFinalJeopardy ? 0 : effectivePoints
        clue.question = question
        clue.answer = answer

        switch media {
        case .none:
            clue.imageData = nil
            clue.audioData = nil
            clue.videoFileName = nil
        case .image(let data):
            clue.imageData = data
            clue.audioData = nil
            clue.videoFileName = nil
        case .audio(let data):
            clue.imageData = nil
            clue.audioData = data
            clue.videoFileName = nil
        case .video(let filename):
            clue.imageData = nil
            clue.audioData = nil
            clue.videoFileName = filename
        }
        clue.answerImageData = answerImageData

        clue.isDailyDouble = !isFinalJeopardy && kind == .dailyDouble
        clue.isMultiplePeople = !isFinalJeopardy && kind == .multiplePeople

        let built = isMultipleChoice ? builtChoiceOptions() : nil
        clue.isMultipleChoice = built != nil
        clue.choiceOptions = built?.options ?? []
        clue.correctChoiceIndex = built?.correctIndex ?? 0
        clue.eliminatedChoiceIndices = []
        clue.fiftyFiftyUsed = false
    }

    /// Builds a brand-new `Clue` from this draft (Add flow).
    func makeClue(isFinalJeopardy: Bool) -> Clue {
        let built = isMultipleChoice ? builtChoiceOptions() : nil
        var videoFileName: String?
        var imageData: Data?
        var audioData: Data?
        switch media {
        case .none: break
        case .image(let data): imageData = data
        case .audio(let data): audioData = data
        case .video(let filename): videoFileName = filename
        }

        return Clue(
            category: isFinalJeopardy ? "Final Jeopardy" : category,
            question: question,
            answer: answer,
            points: isFinalJeopardy ? 0 : effectivePoints,
            imageData: imageData,
            videoFileName: videoFileName,
            audioData: audioData,
            answerImageData: answerImageData,
            isFinalJeopardy: isFinalJeopardy,
            isDailyDouble: !isFinalJeopardy && kind == .dailyDouble,
            isMultiplePeople: !isFinalJeopardy && kind == .multiplePeople,
            isMultipleChoice: built != nil,
            choiceOptions: built?.options ?? [],
            correctChoiceIndex: built?.correctIndex ?? 0
        )
    }
}
