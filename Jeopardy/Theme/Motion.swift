//
//  Motion.swift
//  Jeopardy
//
//  Small helpers for honoring System Settings ▸ Accessibility ▸ Display ▸
//  Reduce motion (SwiftUI exposes it as \.accessibilityReduceMotion).
//
//  What changes when it's on: movement and scaling (slide-ups, springs,
//  hover grow, zoom) are replaced with instant changes or simple fades.
//  Layout, content and behavior stay identical. Fades are kept because
//  they don't create the sense of motion that triggers vestibular
//  discomfort.
//

import SwiftUI

/// Runs `body` inside `withAnimation(animation)`, or with no animation at all
/// when Reduce Motion is on.
func withMotionPreference(reduceMotion: Bool, _ animation: Animation = .default, _ body: () -> Void) {
    if reduceMotion {
        body()
    } else {
        withAnimation(animation, body)
    }
}

extension AnyTransition {
    /// `.move(edge:)` + fade normally; just a fade under Reduce Motion.
    static func slideAndFade(edge: Edge, reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .move(edge: edge).combined(with: .opacity)
    }
}
