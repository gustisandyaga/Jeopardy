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

    @State private var editingClue: Clue?

    private let columnWidth: CGFloat = 200
    private let columnSpacing: CGFloat = 20

    var categories: [String] {
        Array(Set(clues.map { $0.category })).sorted()
    }

    var body: some View {
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
                    HStack(alignment: .top, spacing: columnSpacing) {
                        Spacer(minLength: 0)
                        ForEach(categories, id: \.self) { category in
                            CategoryHeader(title: category)
                                .frame(width: columnWidth)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 15)
                    .zIndex(1)

                    // Only this part scrolls vertically.
                    ScrollView(.vertical) {
                        HStack(alignment: .top, spacing: columnSpacing) {
                            Spacer(minLength: 0)
                            ForEach(categories, id: \.self) { category in
                                VStack(spacing: 15) {
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
        .background(Color.black.opacity(0.05))
        .onAppear {
            selectedPoints = 0
        }
        .sheet(item: $editingClue) { clue in
            ClueFormView(mode: .edit(clue))
        }
    }
}
