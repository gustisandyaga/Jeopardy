//
//  CategoryInfo.swift
//  Jeopardy
//
//  Holds metadata for a category that isn't tied to any single clue —
//  currently just the "how to play" rules text shown from the CategoryHeader
//  info button. Matched to a category purely by name (Clue.category String),
//  since categories aren't a first-class relationship in this model yet.
//

import Foundation
import SwiftData

@Model
class CategoryInfo {
    var name: String
    var rulesText: String?

    init(name: String, rulesText: String? = nil) {
        self.name = name
        self.rulesText = rulesText
    }
}
