//
//  CategoryHeader.swift
//  Jeopardy
//
//  The blue category tile at the top of each column on the board.
//  Also owns two small popups reached via the icon buttons in its corner:
//   - an (i) info button showing/editing that category's rules (CategoryInfo.rulesText)
//   - a pencil button to rename the category, which cascades to every Clue
//     that currently uses this category name.
//

import SwiftUI
import SwiftData

struct CategoryHeader: View {
    let title: String
    @Environment(\.modelContext) private var modelContext

    @State private var isShowingRules = false
    @State private var isEditingRules = false
    @State private var rulesDraft = ""

    @State private var isShowingRename = false
    @State private var renameDraft = ""

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Text(title.uppercased())
                .font(.system(size: 16, weight: .black))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(Color.blue.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(8)
                .shadow(radius: 2)

            HStack(spacing: 6) {
                Button {
                    renameDraft = title
                    isShowingRename = true
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundColor(.white.opacity(0.85))
                }
                .buttonStyle(.plain)
                .help("Rename category")

                Button {
                    rulesDraft = fetchOrCreateCategoryInfo().rulesText ?? ""
                    isEditingRules = false
                    isShowingRules = true
                } label: {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.white.opacity(0.85))
                }
                .buttonStyle(.plain)
                .help("Category rules")
            }
            .padding(6)
        }
        .popover(isPresented: $isShowingRules) {
            rulesPopover
        }
        .sheet(isPresented: $isShowingRename) {
            renameSheet
        }
    }

    // MARK: - Rules popover

    private var rulesPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.headline)

            if isEditingRules {
                TextEditor(text: $rulesDraft)
                    .frame(minWidth: 260, minHeight: 140)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3)))
            } else {
                ScrollView {
                    Text(rulesDraft.isEmpty ? "No rules setup for this currently" : rulesDraft)
                        .foregroundColor(rulesDraft.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minWidth: 260, minHeight: 140)
            }

            HStack {
                if isEditingRules {
                    Button("Cancel") {
                        rulesDraft = fetchOrCreateCategoryInfo().rulesText ?? ""
                        isEditingRules = false
                    }
                    Spacer()
                    Button("Save") {
                        saveRules()
                        isEditingRules = false
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Spacer()
                    Button("Edit Rules") { isEditingRules = true }
                }
            }
        }
        .padding()
        .frame(width: 300)
    }

    // MARK: - Rename sheet

    private var renameSheet: some View {
        VStack(spacing: 16) {
            Text("Rename Category").font(.headline)
            TextField("Category name", text: $renameDraft)
                .textFieldStyle(.roundedBorder)
            Text("This renames the category for every clue currently under \"\(title)\".")
                .font(.caption)
                .foregroundColor(.secondary)
            HStack {
                Button("Cancel") { isShowingRename = false }
                Spacer()
                Button("Save") {
                    renameCategory()
                    isShowingRename = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(renameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 340)
    }

    // MARK: - Data helpers

    private func fetchOrCreateCategoryInfo() -> CategoryInfo {
        let target = title
        let descriptor = FetchDescriptor<CategoryInfo>(predicate: #Predicate<CategoryInfo> { info in
            info.name == target
        })
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }
        let created = CategoryInfo(name: target)
        modelContext.insert(created)
        return created
    }

    private func saveRules() {
        let info = fetchOrCreateCategoryInfo()
        info.rulesText = rulesDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        try? modelContext.save()
    }

    private func renameCategory() {
        let newName = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty, newName != title else { return }

        let oldTitle = title

        // Move every clue in this category over to the new name
        let clueDescriptor = FetchDescriptor<Clue>(predicate: #Predicate<Clue> { clue in
            clue.category == oldTitle
        })
        if let clues = try? modelContext.fetch(clueDescriptor) {
            for clue in clues {
                clue.category = newName
            }
        }

        // Rename (or merge into) the CategoryInfo record
        let info = fetchOrCreateCategoryInfo()
        let newNameDescriptor = FetchDescriptor<CategoryInfo>(predicate: #Predicate<CategoryInfo> { existing in
            existing.name == newName
        })
        let existingInfoForNewName = try? modelContext.fetch(newNameDescriptor).first

        if let existingInfoForNewName, existingInfoForNewName !== info {
            // A category with the target name already exists — merge into it,
            // keeping its rules unless it doesn't have any set yet.
            if (existingInfoForNewName.rulesText ?? "").isEmpty {
                existingInfoForNewName.rulesText = info.rulesText
            }
            modelContext.delete(info)
        } else {
            info.name = newName
        }

        try? modelContext.save()
    }
}
