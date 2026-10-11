//
//  ClueTileView.swift
//  Jeopardy
//
//  One interactive board tile: the visual card (ClueCardView) as a link to
//  its ClueDetailView, plus every way to act on it —
//   - right-click context menu,
//   - a "⋯" button that fades in on hover (Nielsen #6 recognition over
//     recall: the same actions used to exist ONLY in the right-click menu,
//     with nothing hinting that they were there),
//   - VoiceOver custom actions (VoiceOver users can't right-click or hover).
//
//  The "⋯" menu is a SIBLING of the NavigationLink, not inside its label, so
//  clicking it can't also open the clue or fire the link's simultaneous tap
//  gesture (which sets selectedPoints/activeClue).
//

import SwiftUI
import SwiftData

struct ClueTileView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(BoardTheme.storageKey) private var boardThemeRaw: String = BoardTheme.parchment.rawValue

    let clue: Clue
    @Binding var selectedPoints: Int
    @Binding var activeClue: Clue?
    var onEdit: () -> Void

    @State private var isHovering = false
    @State private var isConfirmingDelete = false

    private var theme: BoardTheme {
        BoardTheme(rawValue: boardThemeRaw) ?? .parchment
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            NavigationLink(destination: ClueDetailView(clue: clue, selectedPoints: $selectedPoints, activeClue: $activeClue)) {
                ClueCardView(clue: clue)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(TapGesture().onEnded {
                selectedPoints = clue.points
                activeClue = clue
            })
            .accessibilityHint("Opens the clue")
            .accessibilityAction(named: "Edit Clue") { onEdit() }
            .accessibilityAction(named: "Reactivate Clue") { clue.reactivate() }
            .accessibilityAction(named: "Delete Clue") { isConfirmingDelete = true }

            hoverMenu
        }
        .onHover { isHovering = $0 }
        .contextMenu { actionButtons }
        // (Nielsen #5 error prevention) Deleting also removes the clue's
        // attached media (including its managed video file), so it can't be
        // undone — say so before doing it.
        .confirmationDialog(
            "Delete this \(clue.points)-point clue from \(clue.category)?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete Clue", role: .destructive) { deleteClue() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This also deletes its attached media and can't be undone.")
        }
    }

    /// Shared by the context menu and the hover "⋯" menu so they can't drift.
    @ViewBuilder
    private var actionButtons: some View {
        Button {
            onEdit()
        } label: {
            Label("Edit Clue", systemImage: "pencil")
        }
        Button(role: .destructive) {
            isConfirmingDelete = true
        } label: {
            Label("Delete Clue", systemImage: "trash")
        }
        Button {
            clue.reactivate()
        } label: {
            Label("Reactivate Clue", systemImage: "arrow.counterclockwise")
        }
        .disabled(!clue.isOpened && clue.eliminatedChoiceIndices.isEmpty && !clue.fiftyFiftyUsed)
    }

    private var hoverMenu: some View {
        Menu {
            actionButtons
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(clue.isOpened ? theme.openedText : .white)
                .frame(width: 28, height: 28)
                .background(
                    Circle().fill(clue.isOpened ? Color.black.opacity(0.10) : Color.white.opacity(0.16))
                )
                .contentShape(Circle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .padding(8)
        // Invisible AND inert until the pointer is over the tile, so the
        // empty corner never swallows clicks meant for the link.
        .opacity(isHovering ? 1 : 0)
        .allowsHitTesting(isHovering)
        // VoiceOver gets the same actions as custom actions on the tile.
        .accessibilityHidden(true)
        .help("Edit, delete, or reactivate this clue")
    }

    private func deleteClue() {
        // Clean up any managed video file before removing the clue itself
        MediaStore.deleteVideo(filename: clue.videoFileName)
        modelContext.delete(clue)
    }
}
