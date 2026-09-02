//
//  Clue.swift
//  Jeopardy
//
//  Created by Gusti Sandyaga Putra Wardhana on 30/04/26.
//

import Foundation
import SwiftData

@Model
class Clue {
    var category: String
    var question: String
    var answer: String
    var points: Int

    // Board state
    var isOpened: Bool = false
    var isFinalJeopardy: Bool = false

    // Special clue types — surfaced as a full-screen announcement (with audio)
    // before the question/answer is shown. Host-controlled via ClueFormView.
    // In practice these are mutually exclusive (the form treats them as a
    // single picker), but they're stored as separate bools so nothing stops
    // a future rule variant from wanting both.
    var isDailyDouble: Bool = false
    var isMultiplePeople: Bool = false

    // MARK: Multiple choice (optional)
    //
    // When enabled, ClueDetailView shows `choiceOptions` as tappable rows
    // instead of (or alongside) the free-text `answer`. Tapping a wrong
    // option crosses it out for everyone still guessing; tapping the
    // correct one (or pressing "Reveal Answer") highlights it green. The
    // 50:50 gimmick works by adding two wrong indices to
    // `eliminatedChoiceIndices` directly. `eliminatedChoiceIndices` is
    // per-playthrough state, the same way `isOpened` is — it's reset
    // whenever the clue's options are edited via ClueFormView.
    var isMultipleChoice: Bool = false
    var choiceOptions: [String] = []
    var correctChoiceIndex: Int = 0
    var eliminatedChoiceIndices: [Int] = []

    // Media (optional, pick at most one — see ClueMediaView for display precedence)
    @Attribute(.externalStorage) var imageData: Data?
    @Attribute(.externalStorage) var audioData: Data?
    // Video files are copied into the app's Application Support folder by
    // MediaStore; this stores only the filename within that folder (not a
    // raw external URL, which wouldn't survive the sandbox between launches).
    var videoFileName: String?

    // Optional image shown alongside (or instead of) the text answer, purely
    // to make the reveal more fun for the Host (memes, photo answers, etc).
    // If this is set, ClueFormView no longer requires answer text.
    @Attribute(.externalStorage) var answerImageData: Data?

    init(category: String, question: String, answer: String, points: Int,
         imageData: Data? = nil, videoFileName: String? = nil, audioData: Data? = nil,
         answerImageData: Data? = nil,
         isOpened: Bool = false, isFinalJeopardy: Bool = false,
         isDailyDouble: Bool = false, isMultiplePeople: Bool = false,
         isMultipleChoice: Bool = false, choiceOptions: [String] = [],
         correctChoiceIndex: Int = 0, eliminatedChoiceIndices: [Int] = []) {
        self.category = category
        self.question = question
        self.answer = answer
        self.points = points
        self.imageData = imageData
        self.videoFileName = videoFileName
        self.audioData = audioData
        self.answerImageData = answerImageData
        self.isOpened = isOpened
        self.isFinalJeopardy = isFinalJeopardy
        self.isDailyDouble = isDailyDouble
        self.isMultiplePeople = isMultiplePeople
        self.isMultipleChoice = isMultipleChoice
        self.choiceOptions = choiceOptions
        self.correctChoiceIndex = correctChoiceIndex
        self.eliminatedChoiceIndices = eliminatedChoiceIndices
    }

    /// True if this clue needs a full-screen announcement (Daily Double,
    /// Multiple People, or Final Jeopardy) shown before its question/answer.
    var needsAnnouncement: Bool {
        isDailyDouble || isMultiplePeople || isFinalJeopardy
    }
}
