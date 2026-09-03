import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedPoints: Int = 0
    @State private var activeClue: Clue?
    @State private var isShowingAddClue = false // Control the pop-up
    @State private var isConfirmingLoad = false
    @State private var isConfirmingReset = false

    var body: some View {
        VStack(spacing: 0) {
            NavigationStack {
                VStack(spacing: 0) {
                    BoardGridView(selectedPoints: $selectedPoints, activeClue: $activeClue)
                    FinalJeopardySectionView(selectedPoints: $selectedPoints, activeClue: $activeClue)
                }
                .navigationTitle("Jeopardy Board")
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        // Add Clue Button
                        Button {
                            isShowingAddClue = true
                        } label: {
                            Label("Add Clue", systemImage: "plus.circle.fill")
                        }

                        #if os(macOS)
                        Button {
                            BoardStorage.exportBoard(context: modelContext)
                        } label: {
                            Label("Save Board", systemImage: "square.and.arrow.down")
                        }
                        .help("Save the current board (categories, clues, media) to a file")

                        Button {
                            isConfirmingLoad = true
                        } label: {
                            Label("Load Board", systemImage: "square.and.arrow.up")
                        }
                        .help("Load a board from a file, replacing the current one")
                        #endif

                        Button(role: .destructive) {
                            isConfirmingReset = true
                        } label: {
                            Label("Reset Board", systemImage: "trash")
                        }
                        .foregroundColor(.red)
                        .help("Clear the board or replace it with a 5 × 5 sample board")
                    }
                }
                // This triggers the Add Clue pop-up
                .sheet(isPresented: $isShowingAddClue) {
                    ClueFormView(mode: .add)
                }
                #if os(macOS)
                .confirmationDialog(
                    "Loading a board replaces every category, clue, and Final Jeopardy clue currently on the board. This can't be undone.",
                    isPresented: $isConfirmingLoad,
                    titleVisibility: .visible
                ) {
                    Button("Choose File…", role: .destructive) {
                        BoardStorage.importBoard(context: modelContext)
                    }
                    Button("Cancel", role: .cancel) {}
                }
                #endif
                .confirmationDialog(
                    "Reset Board",
                    isPresented: $isConfirmingReset,
                    titleVisibility: .visible
                ) {
                    Button("Create 5 × 5 Dummy Board") {
                        createDummyBoard()
                    }
                    Button("Clear Board", role: .destructive) {
                        clearBoard()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This replaces all current clues and category rules.")
                }
            }
            
            BottomPlayerBar(activeCluePoints: selectedPoints, activeClue: activeClue)
                .background(Color(NSColor.windowBackgroundColor))
                .shadow(color: .black.opacity(0.1), radius: 5, y: -2)
        }
    }
    
    private func clearBoard() {
        withAnimation {
            do {
                let currentClues = try modelContext.fetch(FetchDescriptor<Clue>())
                currentClues.forEach { MediaStore.deleteVideo(filename: $0.videoFileName) }
                try modelContext.delete(model: Clue.self)
                try modelContext.delete(model: CategoryInfo.self)
                selectedPoints = 0
                try modelContext.save()
            } catch {
                print("Failed to reset board: \(error.localizedDescription)")
            }
        }
    }

    private func createDummyBoard() {
        clearBoard()

        let categories = ["History", "Science", "Movies", "Music", "Geography"]
        let pointValues = [200, 400, 600, 800, 1000]
        withAnimation {
            for category in categories {
                modelContext.insert(CategoryInfo(name: category))
                for (clueIndex, points) in pointValues.enumerated() {
                    modelContext.insert(Clue(
                        category: category,
                        question: "Sample question \(clueIndex + 1) for \(category)",
                        answer: "Sample answer \(clueIndex + 1)",
                        points: points
                    ))
                }
            }
            try? modelContext.save()
        }
    }
}
