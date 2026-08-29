//
//  BoardStorage.swift
//  Jeopardy
//
//  Exports/imports the entire board (categories, clues, media, Final
//  Jeopardy clue) to a single self-contained JSON file so the Host can back
//  up a board or reuse it later. Media (image/audio/video bytes) is embedded
//  as base64 so the .json file is fully portable on its own.
//
//  NOTE: Player rosters/scores are intentionally NOT included — this saves
//  the *board* (questions), not a specific game session's players/scores.
//

import Foundation
import SwiftData
internal import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#endif

struct ClueExport: Codable {
    var category: String
    var question: String
    var answer: String
    var points: Int
    var isOpened: Bool
    var isFinalJeopardy: Bool
    var isDailyDouble: Bool
    var isMultiplePeople: Bool
    var imageDataBase64: String?
    var audioDataBase64: String?
    var videoDataBase64: String?
    var videoFileExtension: String?
    var answerImageDataBase64: String?

    private enum CodingKeys: String, CodingKey {
        case category, question, answer, points, isOpened, isFinalJeopardy
        case isDailyDouble, isMultiplePeople, imageDataBase64, audioDataBase64
        case videoDataBase64, videoFileExtension, answerImageDataBase64
    }

    init(category: String, question: String, answer: String, points: Int, isOpened: Bool,
         isFinalJeopardy: Bool, isDailyDouble: Bool, isMultiplePeople: Bool,
         imageDataBase64: String?, audioDataBase64: String?, videoDataBase64: String?,
         videoFileExtension: String?, answerImageDataBase64: String?) {
        self.category = category
        self.question = question
        self.answer = answer
        self.points = points
        self.isOpened = isOpened
        self.isFinalJeopardy = isFinalJeopardy
        self.isDailyDouble = isDailyDouble
        self.isMultiplePeople = isMultiplePeople
        self.imageDataBase64 = imageDataBase64
        self.audioDataBase64 = audioDataBase64
        self.videoDataBase64 = videoDataBase64
        self.videoFileExtension = videoFileExtension
        self.answerImageDataBase64 = answerImageDataBase64
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            category: try values.decode(String.self, forKey: .category),
            question: try values.decode(String.self, forKey: .question),
            answer: try values.decode(String.self, forKey: .answer),
            points: try values.decode(Int.self, forKey: .points),
            isOpened: try values.decode(Bool.self, forKey: .isOpened),
            isFinalJeopardy: try values.decode(Bool.self, forKey: .isFinalJeopardy),
            isDailyDouble: try values.decodeIfPresent(Bool.self, forKey: .isDailyDouble) ?? false,
            isMultiplePeople: try values.decodeIfPresent(Bool.self, forKey: .isMultiplePeople) ?? false,
            imageDataBase64: try values.decodeIfPresent(String.self, forKey: .imageDataBase64),
            audioDataBase64: try values.decodeIfPresent(String.self, forKey: .audioDataBase64),
            videoDataBase64: try values.decodeIfPresent(String.self, forKey: .videoDataBase64),
            videoFileExtension: try values.decodeIfPresent(String.self, forKey: .videoFileExtension),
            answerImageDataBase64: try values.decodeIfPresent(String.self, forKey: .answerImageDataBase64)
        )
    }
}

struct CategoryInfoExport: Codable {
    var name: String
    var rulesText: String?
}

struct BoardExport: Codable {
    var formatVersion: Int
    var savedAt: Date
    var categories: [CategoryInfoExport]
    var clues: [ClueExport]
}

enum BoardStorage {

    // MARK: - Building/applying an export (platform-independent, testable)

    static func makeExport(context: ModelContext) -> BoardExport? {
        do {
            let clues = try context.fetch(FetchDescriptor<Clue>())
            let categoryInfos = try context.fetch(FetchDescriptor<CategoryInfo>())

            let clueExports: [ClueExport] = clues.map { clue in
                var videoBase64: String?
                var videoExt: String?
                if let filename = clue.videoFileName {
                    let url = MediaStore.url(for: filename)
                    if let data = try? Data(contentsOf: url) {
                        videoBase64 = data.base64EncodedString()
                        videoExt = (filename as NSString).pathExtension
                    }
                }
                
                return ClueExport(
                    category: clue.category,
                    question: clue.question,
                    answer: clue.answer,
                    points: clue.points,
                    isOpened: clue.isOpened,
                    isFinalJeopardy: clue.isFinalJeopardy,
                    isDailyDouble: clue.isDailyDouble,
                    isMultiplePeople: clue.isMultiplePeople,
                    imageDataBase64: clue.imageData?.base64EncodedString(),
                    audioDataBase64: clue.audioData?.base64EncodedString(),
                    videoDataBase64: videoBase64,
                    videoFileExtension: videoExt,
                    answerImageDataBase64: clue.answerImageData?.base64EncodedString()
                )
            }

            let categoryExports = categoryInfos.map {
                CategoryInfoExport(name: $0.name, rulesText: $0.rulesText)
            }

            return BoardExport(formatVersion: 2, savedAt: Date(), categories: categoryExports, clues: clueExports)
        } catch {
            print("BoardStorage: failed to read board — \(error.localizedDescription)")
            return nil
        }
    }

    static func encodedData(from export: BoardExport) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(export)
    }

    /// Replaces the ENTIRE current board (categories + clues) with the
    /// contents of `export`. Destructive — callers should confirm with the
    /// Host first.
    static func applyImport(_ export: BoardExport, to context: ModelContext) {
        do {
            try context.delete(model: Clue.self)
            try context.delete(model: CategoryInfo.self)

            for catExport in export.categories {
                context.insert(CategoryInfo(name: catExport.name, rulesText: catExport.rulesText))
            }

            for clueExport in export.clues {
                var videoFileName: String?
                if let base64 = clueExport.videoDataBase64, let data = Data(base64Encoded: base64) {
                    videoFileName = MediaStore.writeVideoData(data, fileExtension: clueExport.videoFileExtension ?? "mov")
                }

                let clue = Clue(
                    category: clueExport.category,
                    question: clueExport.question,
                    answer: clueExport.answer,
                    points: clueExport.points,
                    imageData: clueExport.imageDataBase64.flatMap { Data(base64Encoded: $0) },
                    videoFileName: videoFileName,
                    audioData: clueExport.audioDataBase64.flatMap { Data(base64Encoded: $0) },
                    answerImageData: clueExport.answerImageDataBase64.flatMap { Data(base64Encoded: $0) },
                    isOpened: clueExport.isOpened,
                    isFinalJeopardy: clueExport.isFinalJeopardy,
                    isDailyDouble: clueExport.isDailyDouble,
                    isMultiplePeople: clueExport.isMultiplePeople
                )
                
                context.insert(clue)
            }

            try context.save()
        } catch {
            print("BoardStorage: failed to apply import — \(error.localizedDescription)")
        }
    }

    // MARK: - macOS file panels

    #if os(macOS)
    static func exportBoard(context: ModelContext) {
        guard let export = makeExport(context: context), let data = encodedData(from: export) else { return }

        let panel = NSSavePanel()
        panel.title = "Save Jeopardy Board"
        panel.nameFieldStringValue = "JeopardyBoard.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try data.write(to: url)
            } catch {
                presentAlert(title: "Couldn't Save Board", message: error.localizedDescription)
            }
        }
    }

    static func importBoard(context: ModelContext) {
        let panel = NSOpenPanel()
        panel.title = "Load Jeopardy Board"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let export = try decoder.decode(BoardExport.self, from: data)
            applyImport(export, to: context)
        } catch {
            presentAlert(title: "Couldn't Load Board", message: error.localizedDescription)
        }
    }

    private static func presentAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
    #endif
}
