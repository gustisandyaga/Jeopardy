//
//  Players.swift
//  Jeopardy
//
//  Created by Gusti Sandyaga Putra Wardhana on 30/04/26.
//

import Foundation
import SwiftData

@Model
class Players: Identifiable {
    
    var name: String
    var score: Int = 0
    /// Final Jeopardy is resolved independently for every player. These
    /// values persist while the Host moves between the announcement, clue,
    /// and answer.
    var finalJeopardyWager: Int = 0
    var finalJeopardyResult: String = "unresolved"
    
    init(name: String, score: Int) {
        self.name = name
        self.score = score
    }
}
