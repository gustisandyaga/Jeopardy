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

/// Auto-expanding, tappable image view. Sized from the image's *real*
/// aspect ratio (like VideoClueView does for video) rather than a flat
/// max-height cap, so wide/tall images get proportionally more room — this
/// pushes the question/answer content below it naturally, since it all
/// lives in the same VStack. Tapping opens ImageLightboxView for a full,
/// zoomable look (pinch/scroll to zoom, drag to pan).
struct ExpandingClueImageView: View {
    let imageData: Data
    var maxWidth: CGFloat = 700
    var maxHeight: CGFloat = 500

    @State private var isShowingLightbox = false

    var body: some View {
        if let nsImage = NSImage(data: imageData) {
            Button {
                isShowingLightbox = true
            } label: {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: maxWidth, maxHeight: maxHeight)
                    .cornerRadius(12)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.caption)
                            .padding(8)
                            .background(.black.opacity(0.55), in: Circle())
                            .foregroundColor(.white)
                            .padding(10)
                    }
            }
            .buttonStyle(.plain)
            .help("Click to zoom in")
            .sheet(isPresented: $isShowingLightbox) {
                ImageLightboxView(nsImage: nsImage)
            }
        }
    }
}

struct ClueMediaView: View {
    let clue: Clue

    var body: some View {
        Group {
            if let imageData = clue.imageData {
                ExpandingClueImageView(imageData: imageData)
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
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showAnswer.toggle()

                    // Play the sound ONLY when revealing
                    if showAnswer {
                        SoundManager.instance.playSound(named: "reveal_ding")
                        // ^ Make sure "reveal_ding" matches your file name in Xcode
                        clue.isOpened = true
                    }
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
}
