//
//  GimmickBadgeView.swift
//  Jeopardy
//
//  Created by Gusti Sandyaga Putra Wardhana on 03/09/26.
//


//
//  GimmickBadgeView.swift
//  Jeopardy
//
//  One small icon on a player's card representing a single gimmick
//  (Phone-a-Friend, 50:50, ...). Hovering reveals a popover with its name
//  and what it does; tapping activates it (see GimmickBar for the actual
//  effect). Used ones are dimmed and can't be tapped again, and a specific
//  reason is shown when it's disabled for some other cause (e.g. another
//  player already used 50:50 on this clue).
//

import SwiftUI

struct GimmickBadgeView: View {
    let gimmick: GimmickType
    let isUsed: Bool
    let isEnabled: Bool
    /// Why this is currently disabled, shown in the hover popover. Ignored
    /// when `isUsed` is true (that has its own message) or when enabled.
    let disabledReason: String?
    let action: () -> Void

    @State private var isHovering = false

    private var iconColor: Color {
        if isUsed { return .secondary.opacity(0.35) }
        return isEnabled ? gimmick.tint : .secondary.opacity(0.5)
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: gimmick.icon)
                .font(.system(size: 15))
                .foregroundColor(iconColor)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.primary.opacity(0.06)))
        }
        .buttonStyle(.plain)
        .disabled(isUsed || !isEnabled)
        .help(isUsed ? "\(gimmick.title) — already used" : gimmick.title)
        .onHover { hovering in
            isHovering = hovering
        }
        .popover(isPresented: $isHovering, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Label(gimmick.title, systemImage: gimmick.icon)
                    .font(.caption.bold())
                    .foregroundColor(gimmick.tint)
                Text(gimmick.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                if isUsed {
                    Text("Already used this game")
                        .font(.caption2.italic())
                        .foregroundColor(.orange)
                } else if !isEnabled {
                    Text(disabledReason ?? "Not available right now")
                        .font(.caption2.italic())
                        .foregroundColor(.secondary)
                }
            }
            .padding(10)
            .frame(width: 220, alignment: .leading)
        }
    }
}