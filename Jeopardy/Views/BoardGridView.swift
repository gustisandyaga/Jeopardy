import SwiftUI
import SwiftData

struct BoardGridView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Clue> { clue in clue.isFinalJeopardy == false },
        sort: [SortDescriptor(\Clue.points)]
    )
    private var clues: [Clue]

    @Binding var selectedPoints: Int
    @Binding var activeClue: Clue?

    /// Entry points surfaced by `EmptyBoardStateView` when the board has no
    /// clues yet. These just call back up to ContentView's existing logic
    /// (createDummyBoard / BoardStorage.importBoard / Add Clue sheet) — no
    /// new board-building logic lives here.
    var onCreateDummyBoard: () -> Void
    var onImportBoard: (() -> Void)?
    var onAddClue: () -> Void

    @State private var editingClue: Clue?

    @AppStorage(BoardGridDensity.storageKey) private var gridDensityRaw: String = BoardGridDensity.comfortable.rawValue
    private var gridDensity: BoardGridDensity {
        BoardGridDensity(rawValue: gridDensityRaw) ?? .comfortable
    }

    private let columnWidth: CGFloat = 200

    var categories: [String] {
        Array(Set(clues.map { $0.category })).sorted()
    }

    /// A category counts as "completed" once it has at least one clue and
    /// every clue under it has been opened. The "at least one" guard stops
    /// a category that's never had clues added from being (incorrectly)
    /// shown as done — vacuous truth on an empty filter would otherwise
    /// mark it complete with nothing actually answered.
    private func isCategoryCompleted(_ category: String) -> Bool {
        let categoryClues = clues.filter { $0.category == category }
        return !categoryClues.isEmpty && categoryClues.allSatisfy { $0.isOpened }
    }

    var body: some View {
        Group {
            if categories.isEmpty {
                EmptyBoardStateView(
                    onCreateDummyBoard: onCreateDummyBoard,
                    onImportBoard: onImportBoard,
                    onAddClue: onAddClue
                )
            } else {
                boardGrid
            }
        }
        // The board's 60% — Parchment. Deliberately scoped to just this
        // grid (not ContentView's outer window or ClueDetailView), so the
        // rest of the app keeps following the system's light/dark mode.
        // See PROJECT.md "Color Theme" addendum.
        .background(Color.jeopardyBackground)
        .onAppear {
            selectedPoints = 0
        }
        .navigationDestination(item: $editingClue) { clue in
            ClueDetailView(clue: clue, selectedPoints: $selectedPoints, activeClue: $activeClue, startInEditMode: true)
        }
    }

    private var boardGrid: some View {
        GeometryReader { geometry in
            // Outer scroll is horizontal-only. Both the header row and the
            // clue grid below live inside it, so they always move together
            // left/right — headers stay lined up over their columns.
            ScrollView(.horizontal) {
                VStack(spacing: 0) {
                    // Sticky header row — deliberately OUTSIDE the vertical
                    // ScrollView below, so it can never scroll away no
                    // matter how far down the Host scrolls to reach the
                    // $1000 row. Opaque background stops clue cards from
                    // visibly sliding underneath it while scrolling.
                    HStack(alignment: .top, spacing: gridDensity.columnSpacing) {
                        Spacer(minLength: 0)
                        ForEach(categories, id: \.self) { category in
                            CategoryHeader(title: category, isCompleted: isCategoryCompleted(category))
                                .frame(width: columnWidth)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 15)
                    .zIndex(1)

                    // Only this part scrolls vertically.
                    ScrollView(.vertical) {
                        HStack(alignment: .top, spacing: gridDensity.columnSpacing) {
                            Spacer(minLength: 0)
                            ForEach(categories, id: \.self) { category in
                                VStack(spacing: gridDensity.rowSpacing) {
                                    let categoryClues = clues.filter { $0.category == category }
                                    ForEach(categoryClues) { clue in
                                        NavigationLink(destination: ClueDetailView(clue: clue, selectedPoints: $selectedPoints, activeClue: $activeClue)) {
                                            ClueCardView(clue: clue, onEdit: { editingClue = clue })
                                                .frame(width: columnWidth, height: 120)
                                        }
                                        .buttonStyle(.plain)
                                        .simultaneousGesture(TapGesture().onEnded {
                                            selectedPoints = clue.points
                                            activeClue = clue
                                        })
                                    }
                                }
                                .frame(width: columnWidth)
                                .padding(.top, 30)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.bottom, 20)
                    }
                    .frame(maxHeight: .infinity)
                }
                .frame(minWidth: geometry.size.width)
                .frame(height: geometry.size.height, alignment: .top)
            }
        }
    }
}
