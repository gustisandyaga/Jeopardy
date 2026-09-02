import SwiftData
import SwiftUI

import AVKit
import AVFoundation
import Combine

struct ClueCardView: View {
    @Environment(\.modelContext) private var modelContext
    let clue: Clue
    var onEdit: () -> Void = {}

    var body: some View {
        VStack(spacing: 6) {
            if clue.isOpened {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.85))
            }
            Text("$\(clue.points)")
                .font(.system(size: 24, weight: .bold, design: .serif))
                .foregroundColor(clue.isOpened ? .white.opacity(0.6) : .yellow)
                .strikethrough(clue.isOpened)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(clue.isOpened ? Color.gray.opacity(0.55) : Color.blue)
        .cornerRadius(8)
        .shadow(radius: 5)
        // --- CONTEXT MENU: edit or delete this clue ---
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Edit Clue", systemImage: "pencil")
            }
            Button(role: .destructive) {
                deleteClue()
            } label: {
                Label("Delete Clue", systemImage: "trash")
            }
        }
    }

    private func deleteClue() {
        // Clean up any managed video file before removing the clue itself
        MediaStore.deleteVideo(filename: clue.videoFileName)
        modelContext.delete(clue)
    }
}

struct ClueMediaView: View {
    let clue: Clue

    var body: some View {
        Group {
            if let imageData = clue.imageData, let nsImage = NSImage(data: imageData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .cornerRadius(12)
            } else if let videoFileName = clue.videoFileName {
                VideoClueView(filename: videoFileName)
            } else if let audioData = clue.audioData {
                AudioPlayerView(audioData: audioData)
                    .frame(maxWidth: 400)
            }
        }
        .padding()
    }
}

// MARK: - Multiple choice options

/// Renders `clue.choiceOptions` as tappable rows. Before the answer is
/// revealed, tapping a wrong option crosses it out (representing "a player
/// guessed this and got it wrong"); tapping the correct option jumps
/// straight to reveal, same as pressing "Reveal Answer". Once revealed, the
/// correct row turns green and everything else is dimmed/struck as
/// appropriate. The 50:50 gimmick eliminates options the same way, just
/// from GimmickBar instead of a tap here.
struct MultipleChoiceOptionsView: View {
    let clue: Clue
    let showAnswer: Bool
    let onCorrectSelected: () -> Void

    private let letters = ["A", "B", "C", "D", "E", "F"]

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
        let letter = index < letters.count ? letters[index] : "\(index + 1)"

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

struct ClueDetailView: View {
    let clue: Clue
    @Binding var selectedPoints: Int
    @Binding var activeClue: Clue?
    @State private var showAnswer = false
    @State private var isEditing = false

    // Shown BEFORE the question/answer for any clue that calls for it
    // (Daily Double, Multiple People Can Answer, or Final Jeopardy). See
    // Clue.needsAnnouncement / ClueAnnouncementView.
    @State private var isShowingAnnouncement: Bool

    init(clue: Clue, selectedPoints: Binding<Int>, activeClue: Binding<Clue?>) {
        self.clue = clue
        self._selectedPoints = selectedPoints
        self._activeClue = activeClue
        self._isShowingAnnouncement = State(initialValue: clue.needsAnnouncement)
    }

    public var announcementKind: AnnouncementKind? {
        if clue.isFinalJeopardy { return .finalJeopardy }
        if clue.isDailyDouble { return .dailyDouble }
        if clue.isMultiplePeople { return .multiplePeople }
        return nil
    }
    
    var body: some View {
        Group {
            if isShowingAnnouncement, let announcementKind {
                ClueAnnouncementView(kind: announcementKind) {
                    withAnimation(.easeInOut) {
                        isShowingAnnouncement = false
                    }
                }
            } else {
                clueContent
            }
        }
        .onAppear { activeClue = clue }
        .onDisappear {
            selectedPoints = 0
            activeClue = nil
        }
    }

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
                Button {
                    isEditing = true
                } label: {
                    Image(systemName: "pencil.circle")
                }
                .buttonStyle(.plain)
                .help("Edit this clue")
            }

            if clue.isDailyDouble || clue.isFinalJeopardy {
                Text(clue.isFinalJeopardy
                     ? "Set each player's wager in the player bar below, then mark each result after revealing the answer."
                     : "Remember to lock in the wager — right-click a player below and choose \u{201C}Adjust Score (Wager)\u{2026}\u{201D}.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Media content appears here
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
                    if let answerImageData = clue.answerImageData, let nsImage = NSImage(data: answerImageData) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 240)
                            .cornerRadius(10)
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
        .sheet(isPresented: $isEditing) {
            ClueFormView(mode: clue.isFinalJeopardy ? .finalJeopardy(clue) : .edit(clue))
        }
    }

    /// Shared by the "Reveal Answer" button and tapping the correct
    /// multiple-choice option — both should have the identical effect.
    private func revealAnswer() {
        guard !showAnswer else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            showAnswer = true
            SoundManager.instance.playSound(named: "reveal_ding")
            // ^ Make sure "reveal_ding" matches your file name in Xcode
            clue.isOpened = true
        }
    }
}
