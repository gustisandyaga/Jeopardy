//
//  FinalJeopardySectionView.swift
//  Jeopardy
//
//  Optional bonus round shown below BoardGridView. If the Host hasn't set
//  one up, this is just a slim "Add Final Jeopardy Clue" row. Once a clue
//  exists it shows a compact, clickable summary row.
//

import SwiftUI
import SwiftData

struct FinalJeopardySectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Clue> { clue in clue.isFinalJeopardy == true })
    private var finalJeopardyClues: [Clue]

    @Binding var selectedPoints: Int
    @Binding var activeClue: Clue?

    @State private var isConfirmingRemove = false

    private var finalClue: Clue? { finalJeopardyClues.first }

    var body: some View {
        // No Divider and no outer top padding: the board's backdrop ends
        // exactly where this footer's window-colored region begins, and that
        // color change IS the separator (Gestalt common region). The old
        // Divider plus `.padding(.vertical, 8)` left an 8pt strip of bare
        // window color above a stray line.
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "star.fill").foregroundColor(.jeopardyGold)
                    .accessibilityHidden(true)
                Text("FINAL JEOPARDY").font(.system(size: 14, weight: .heavy))
                Spacer()

                if finalClue == nil {
                    NavigationLink {
                        AddClueScreen(isFinalJeopardy: true)
                    } label: {
                        Label("Add Final Jeopardy Clue", systemImage: "plus.circle")
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(role: .destructive) {
                        isConfirmingRemove = true
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove Final Jeopardy clue")
                }
            }
            .padding(.horizontal)

            if let finalClue {
                NavigationLink(destination: ClueDetailView(clue: finalClue, selectedPoints: $selectedPoints, activeClue: $activeClue)) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Final Jeopardy Ready!")
                                .font(.subheadline)
                                .lineLimit(2)
                                .foregroundColor(.primary)
                            Text(finalClue.isOpened ? "Opened" : "Not opened yet — tap to open or edit")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right.circle.fill")
                            .foregroundColor(.jeopardyInfo)
                            .accessibilityHidden(true)
                    }
                    .padding()
                    .background(Color.jeopardyInfo.opacity(0.08))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .simultaneousGesture(TapGesture().onEnded {
                    selectedPoints = 0
                    activeClue = finalClue
                })
            } else {
                Text("Optional — add a Final Jeopardy clue to play a bonus round after the board is cleared.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom)
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        // (Nielsen #5) Removing also deletes the clue's attached media.
        .confirmationDialog(
            "Remove the Final Jeopardy clue?",
            isPresented: $isConfirmingRemove,
            titleVisibility: .visible
        ) {
            Button("Remove Clue", role: .destructive) { deleteFinalClue() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This also deletes its attached media and can't be undone.")
        }
    }

    private func deleteFinalClue() {
        guard let finalClue else { return }
        MediaStore.deleteVideo(filename: finalClue.videoFileName)
        modelContext.delete(finalClue)
    }
}
