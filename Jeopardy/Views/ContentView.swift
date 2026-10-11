import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedPoints: Int = 0
    @State private var activeClue: Clue?
    @State private var isShowingAddClue = false // Control the pop-up
    @State private var isConfirmingLoad = false
    @State private var isConfirmingReset = false
    @State private var isConfirmingReactivateAll = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Every clue (including Final Jeopardy), so Reactivate All can tell
    /// whether there's anything to reactivate.
    @Query private var allClues: [Clue]
    private var playedClues: [Clue] {
        allClues.filter { $0.isOpened || !$0.eliminatedChoiceIndices.isEmpty || $0.fiftyFiftyUsed }
    }

    @AppStorage(BoardTheme.storageKey) private var boardThemeRaw: String = BoardTheme.parchment.rawValue
    private var boardTheme: BoardTheme {
        BoardTheme(rawValue: boardThemeRaw) ?? .parchment
    }

    @AppStorage(BoardGridDensity.storageKey) private var gridDensityRaw: String = BoardGridDensity.comfortable.rawValue
    private var gridDensity: BoardGridDensity {
        BoardGridDensity(rawValue: gridDensityRaw) ?? .comfortable
    }

    var body: some View {
        VStack(spacing: 0) {
            NavigationStack {
                VStack(spacing: 0) {
                    BoardGridView(
                        selectedPoints: $selectedPoints,
                        activeClue: $activeClue,
                        onCreateDummyBoard: createDummyBoard,
                        onImportBoard: importBoardAction,
                        onAddClue: { isShowingAddClue = true }
                    )
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

                        // Accessibility options for the Hermann grid illusion some
                        // people see at the board's regular intersections. Two
                        // independent levers, one menu:
                        //  - Layout: Comfortable (moderate gaps, soft edges) vs
                        //    Tight (near-zero gaps — removes the "streets").
                        //  - Theme: Parchment (light) vs Broadcast (dark backdrop,
                        //    ~1.2:1 against the cards instead of 14.7:1).
                        // See BoardGridDensity.swift, BoardTheme.swift, PROJECT.md.
                        Menu {
                            Picker("Board Layout", selection: $gridDensityRaw) {
                                ForEach(BoardGridDensity.allCases) { density in
                                    Label(density.title, systemImage: density.icon)
                                        .tag(density.rawValue)
                                }
                            }
                            .pickerStyle(.inline)

                            Picker("Board Theme", selection: $boardThemeRaw) {
                                ForEach(BoardTheme.allCases) { theme in
                                    Label(theme.title, systemImage: theme.icon)
                                        .tag(theme.rawValue)
                                }
                            }
                            .pickerStyle(.inline)
                        } label: {
                            Label("Board Appearance", systemImage: "paintpalette")
                        }
                        .help("Board Appearance — Layout: \(gridDensity.title) (\(gridDensity.subtitle)). Theme: \(boardTheme.title) (\(boardTheme.subtitle)). Accessibility options for reducing the grid effect some people see on the board.")

                        Button {
                            isConfirmingReactivateAll = true
                        } label: {
                            Label("Reactivate All", systemImage: "arrow.counterclockwise")
                        }
                        .disabled(playedClues.isEmpty)
                        .help(playedClues.isEmpty
                              ? "Nothing to reactivate — no clue has been played yet"
                              : "Make every clue playable again, to play this board anew")

                        Button(role: .destructive) {
                            isConfirmingReset = true
                        } label: {
                            Label("Reset Board", systemImage: "trash")
                        }
                        .foregroundColor(.jeopardyIncorrect)
                        .help("Clear the board or replace it with a 5 × 5 sample board")
                    }
                }
                // This triggers the Add Clue pop-up
                .navigationDestination(isPresented: $isShowingAddClue) {
                    AddClueScreen()
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
                    "Reactivate every clue?",
                    isPresented: $isConfirmingReactivateAll,
                    titleVisibility: .visible
                ) {
                    Button("Reactivate All") { reactivateAllClues() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("\(playedClues.count) played clue\(playedClues.count == 1 ? "" : "s") will become unplayed, with crossed-out options and 50:50 cleared. Players and scores aren't changed.")
                }
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

    /// nil on non-macOS platforms — mirrors the toolbar's existing
    /// `#if os(macOS)` guard around Load Board, so the empty-state tile
    /// simply doesn't render there instead of calling into an
    /// unavailable NSOpenPanel-based flow.
    private var importBoardAction: (() -> Void)? {
        #if os(macOS)
        return { BoardStorage.importBoard(context: modelContext) }
        #else
        return nil
        #endif
    }
    
    /// Resets playthrough state on every clue (Final Jeopardy included) so a
    /// finished or imported board can be played again. Content is untouched;
    /// players/scores are separate (see BottomPlayerBar's reset).
    private func reactivateAllClues() {
        withMotionPreference(reduceMotion: reduceMotion) {
            allClues.forEach { $0.reactivate() }
            selectedPoints = 0
            try? modelContext.save()
        }
    }

    private func clearBoard() {
        withMotionPreference(reduceMotion: reduceMotion) {
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
        withMotionPreference(reduceMotion: reduceMotion) {
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
