//
//  JeopardyApp.swift
//  Jeopardy
//
//  Created by Gusti Sandyaga Putra Wardhana on 30/04/26.
//

import SwiftUI
import SwiftData

@main
struct JeopardyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // Make sure ALL model types are listed here
        .modelContainer(for: [Clue.self, Players.self, CategoryInfo.self])
    }
}
