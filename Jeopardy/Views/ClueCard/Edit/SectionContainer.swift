//
//  SectionContainer.swift
//  Jeopardy
//
//  Created by Gusti Sandyaga Putra Wardhana on 16/09/26.
//


//
//  SectionContainer.swift
//  Jeopardy
//
//  Lives in Views/ClueCard/Edit/. The shared "title + optional help text +
//  rounded tinted background" wrapper used by every section of the clue
//  editor (Gestalt common region — each conceptual group gets its own
//  visible boundary instead of relying on whitespace alone). Promoted from
//  a private method on ClueEditorView to a real, standalone view so the
//  extracted MediaAttachmentSection and MultipleChoiceEditSection can use
//  it too, instead of duplicating the same boilerplate in each file.
//

import SwiftUI

struct SectionContainer<Content: View>: View {
    let title: String
    var help: String?
    let isShowingHelp: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            if isShowingHelp, let help {
                Text(help)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.06)))
    }
}