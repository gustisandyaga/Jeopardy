import SwiftUI
import SwiftData

struct BoardGridView: View {
    @Environment(\.modelContext) private var modelContext
    // Final Jeopardy's clue lives in the same model but is excluded from the
    // main grid — it's surfaced separately by FinalJeopardySectionView.
    @Query(
        filter: #Predicate<Clue> { clue in clue.isFinalJeopardy == false },
        sort: [SortDescriptor(\Clue.points)]
    )
    private var clues: [Clue]

    // Binding allows this view to update the state owned by ContentView
    @Binding var selectedPoints: Int
    @Binding var activeClue: Clue?

    @State private var editingClue: Clue?

    var categories: [String] {
        Array(Set(clues.map { $0.category })).sorted()
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical]) {
                VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: 20) {
                        Spacer(minLength: 0)
                        
                        ForEach(categories, id: \.self) { category in
                            VStack(spacing: 15) {
                                CategoryHeader(title: category)
                                    .frame(width: 200)
                                
                                let categoryClues = clues.filter { $0.category == category }
                                
                                ForEach(categoryClues) { clue in
                                    // Pass the binding ($selectedPoints) into ClueDetailView
                                    NavigationLink(destination: ClueDetailView(clue: clue, selectedPoints: $selectedPoints, activeClue: $activeClue)) {
                                        ClueCardView(clue: clue, onEdit: { editingClue = clue })
                                            .frame(width: 200, height: 120)
                                    }
                                    .buttonStyle(.plain)
                                    .simultaneousGesture(TapGesture().onEnded {
                                        // Set the points when entering
                                        selectedPoints = clue.points
                                        activeClue = clue
                                    })
                                }
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 40)
                    Spacer(minLength: 0)
                }
                .frame(minWidth: geometry.size.width, minHeight: geometry.size.height)
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
