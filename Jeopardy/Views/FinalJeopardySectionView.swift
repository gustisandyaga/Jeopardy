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

    @State private var isPresentingForm = false

    private var finalClue: Clue? { finalJeopardyClues.first }

    var body: some View {
        VStack(spacing: 8) {
            Divider()
            HStack {
                Image(systemName: "star.fill").foregroundColor(.yellow)
                Text("FINAL JEOPARDY").font(.system(size: 14, weight: .heavy))
                Spacer()

                if finalClue != nil {
                    Button {
                        isPresentingForm = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .buttonStyle(.plain)

                    Button(role: .destructive) {
                        deleteFinalClue()
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        isPresentingForm = true
                    } label: {
                        Label("Add Final Jeopardy Clue", systemImage: "plus.circle")
                    }
                    .buttonStyle(.plain)
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
                            Text(finalClue.isOpened ? "Opened" : "Not opened yet")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right.circle.fill")
                            .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.08))
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
            }
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $isPresentingForm) {
            ClueFormView(mode: .finalJeopardy(finalClue))
        }
    }

    private func deleteFinalClue() {
        guard let finalClue else { return }
        MediaStore.deleteVideo(filename: finalClue.videoFileName)
        modelContext.delete(finalClue)
    }
}
