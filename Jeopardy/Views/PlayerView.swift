import SwiftUI
import SwiftData

struct PlayerView: View {
    // 1. Access the context from the environment
        @Environment(\.modelContext) private var modelContext
    
    @Bindable var player: Players
    let currentCluePoints: Int
    let isFinalJeopardyActive: Bool

    @State private var isAdjustingScore = false
    @State private var isConfirmingReset = false
    
    var body: some View {
        VStack(spacing: 12) {
            TextField("Name", text: $player.name)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)
            
            Text("\(player.score)")
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
            
            if isFinalJeopardyActive {
                finalJeopardyControls
            } else {
                HStack {
                    Button("-") { player.score -= currentCluePoints }
                    Button("+") { player.score += currentCluePoints }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(width: 180, height: isFinalJeopardyActive ? 160 : 120)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(10)
        .shadow(radius: 2)
        .contextMenu {
                Button {
                    isAdjustingScore = true
                } label: {
                    Label("Adjust Score (Wager)…", systemImage: "dollarsign.circle")
                }

                Button(role: .destructive) {
                    isConfirmingReset = true
                } label: {
                    Label("Reset Score to 0", systemImage: "arrow.counterclockwise")
                }

                Divider()

                Button(role: .destructive) {
                    deletePlayer()
                } label: {
                    Label("Remove Player", systemImage: "trash")
                }
            }
        .confirmationDialog(
            "Reset \(player.name)'s score to $0?",
            isPresented: $isConfirmingReset,
            titleVisibility: .visible
        ) {
            Button("Reset Score", role: .destructive) { player.score = 0 }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $isAdjustingScore) {
            ScoreAdjustmentView(player: player, suggestedWager: currentCluePoints)
        }
    }

    @ViewBuilder
    private var finalJeopardyControls: some View {
        if player.finalJeopardyResult == "unresolved" {
            TextField("Wager", value: $player.finalJeopardyWager, format: .number)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)
                .help("This player's Final Jeopardy wager")
                .onSubmit { try? modelContext.save() }

            HStack(spacing: 8) {
                Button("Incorrect") { resolveFinalJeopardy(as: "incorrect") }
                    .foregroundColor(.red)
                Button("Correct") { resolveFinalJeopardy(as: "correct") }
            }
            .buttonStyle(.bordered)
            .disabled(player.finalJeopardyWager <= 0)
        } else {
            Text("Wager: $\(player.finalJeopardyWager) — \(resultLabel)")
                .font(.caption)
                .foregroundColor(player.finalJeopardyResult == "correct" ? .green : .red)
            Button("Undo Result", action: undoFinalJeopardyResult)
                .buttonStyle(.bordered)
        }
    }

    private var resultLabel: String {
        player.finalJeopardyResult == "correct" ? "Correct" : "Incorrect"
    }

    private func resolveFinalJeopardy(as result: String) {
        guard player.finalJeopardyResult == "unresolved", player.finalJeopardyWager > 0 else { return }
        player.score += result == "correct" ? player.finalJeopardyWager : -player.finalJeopardyWager
        player.finalJeopardyResult = result
        try? modelContext.save()
    }

    private func undoFinalJeopardyResult() {
        guard player.finalJeopardyResult != "unresolved" else { return }
        player.score += player.finalJeopardyResult == "correct" ? -player.finalJeopardyWager : player.finalJeopardyWager
        player.finalJeopardyResult = "unresolved"
        try? modelContext.save()
    }
    
    // 2. The core deletion logic
        private func deletePlayer() {
            // This marks the object for deletion in the database
            modelContext.delete(player)
            
            // Note: You do not need to manually call 'save()' unless
            // you have disabled autosave in your ModelContainer.
        }
}

// MARK: - Manual / wager-style score adjustment

/// Lets the Host apply a custom point change to one player's score — the
/// mechanism used for Daily Double and Final Jeopardy wagers (where the
/// amount at stake isn't one of the fixed board values) as well as any
/// other manual correction. "Correct" adds the amount, "Incorrect"
/// subtracts it, and "Set Score To…" overwrites it directly.
struct ScoreAdjustmentView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var player: Players
    var suggestedWager: Int = 0

    @State private var amountText: String = ""

    private var amount: Int {
        Int(amountText.trimmingCharacters(in: .whitespaces)) ?? 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Player")
                        Spacer()
                        Text(player.name).foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Current Score")
                        Spacer()
                        Text("$\(player.score)").foregroundColor(.secondary)
                    }
                }

                Section("Wager / Adjustment Amount") {
                    TextField("Amount", text: $amountText)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                    if suggestedWager > 0 {
                        Button("Use Clue Value ($\(suggestedWager))") {
                            amountText = String(suggestedWager)
                        }
                    }
                }

                Section("Apply") {
                    Button {
                        player.score += amount
                        dismiss()
                    } label: {
                        Label("Mark Correct (+$\(max(amount, 0)))", systemImage: "checkmark.circle.fill")
                    }
                    .disabled(amount <= 0)

                    Button {
                        player.score -= amount
                        dismiss()
                    } label: {
                        Label("Mark Incorrect (-$\(max(amount, 0)))", systemImage: "xmark.circle.fill")
                    }
                    .disabled(amount <= 0)
                    .foregroundColor(.red)

                    Button {
                        player.score = amount
                        dismiss()
                    } label: {
                        Label("Set Score To $\(amount)", systemImage: "equal.circle")
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Adjust Score")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .frame(minWidth: 360, minHeight: 380)
            .onAppear {
                if suggestedWager > 0 {
                    amountText = String(suggestedWager)
                }
            }
        }
    }
}

struct BottomPlayerBar: View {
    @Environment(\.modelContext) private var modelContext // Needed to save new players
    @Query private var players: [Players]
    let activeCluePoints: Int
    let activeClue: Clue?

    @State private var isConfirmingResetAll = false
    @State private var isConfirmingResetFinalWagers = false

    private var isFinalJeopardyActive: Bool { activeClue?.isFinalJeopardy == true }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title and Add Button
            HStack {
                Spacer()
                Text("Players")
                    .font(.headline)
                
                Button(action: addPlayer) { // Call the function here
                    Image(systemName: "person.badge.plus")
                }
                .buttonStyle(.plain)
                .help("Add Player")

                if !players.isEmpty {
                    Button {
                        isConfirmingResetAll = true
                    } label: {
                        Image(systemName: "arrow.counterclockwise.circle")
                    }
                    .buttonStyle(.plain)
                    .help("Reset All Scores to $0")
                }
                if isFinalJeopardyActive, !players.isEmpty {
                    Button {
                        isConfirmingResetFinalWagers = true
                    } label: {
                        Label("Reset Final Wagers", systemImage: "dollarsign.arrow.circlepath")
                    }
                    .buttonStyle(.plain)
                    .help("Clear every Final Jeopardy wager and result without changing scores")
                }
                Spacer()
            }
            .padding(.horizontal)
            .confirmationDialog(
                "Reset every player's score to $0?",
                isPresented: $isConfirmingResetAll,
                titleVisibility: .visible
            ) {
                Button("Reset All Scores", role: .destructive) { resetAllScores() }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog(
                "Clear every Final Jeopardy wager and result? Scores will not change.",
                isPresented: $isConfirmingResetFinalWagers,
                titleVisibility: .visible
            ) {
                Button("Clear Final Wagers", role: .destructive) { resetFinalJeopardyWagers() }
                Button("Cancel", role: .cancel) {}
            }

            // The Centering Area
            GeometryReader { geometry in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        Spacer(minLength: 0)
                        
                        ForEach(players) { player in
                            PlayerView(
                                player: player,
                                currentCluePoints: activeCluePoints,
                                isFinalJeopardyActive: isFinalJeopardyActive
                            )
                        }
                        
                        Spacer(minLength: 0)
                    }
                    .frame(minWidth: geometry.size.width)
                }
            }
            .frame(height: isFinalJeopardyActive ? 180 : 140)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Logic
    
    private func addPlayer() {
        // Create a new player with a default name
        let newPlayer = Players(name: "New Player", score: 0)
        
        // Insert it into the SwiftData context
        modelContext.insert(newPlayer)
        
        // SwiftData automatically saves, and the @Query updates the UI!
    }

    private func resetAllScores() {
        for player in players {
            player.score = 0
        }
    }

    private func resetFinalJeopardyWagers() {
        for player in players {
            player.finalJeopardyWager = 0
            player.finalJeopardyResult = "unresolved"
        }
        try? modelContext.save()
    }
}
