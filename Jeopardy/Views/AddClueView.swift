//
//  AddClueView.swift
//  Jeopardy
//
//  Created by Gusti Sandyaga Putra Wardhana on 08/05/26.
//
//  Renamed in spirit to "ClueFormView" — this single form now handles
//  adding a new clue, editing an existing clue, and adding/editing the
//  optional Final Jeopardy clue, all driven by ClueFormMode.
//

import SwiftUI
import SwiftData
internal import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

enum ClueFormMode {
    case add
    case edit(Clue)
    case finalJeopardy(Clue?)
    
    var existingClue: Clue? {
        switch self {
        case .add: return nil
        case .edit(let clue): return clue
        case .finalJeopardy(let clue): return clue
        }
    }
    
    var isFinalJeopardyMode: Bool {
        if case .finalJeopardy = self { return true }
        return false
    }
    
    var navigationTitle: String {
        switch self {
        case .add: return "New Clue"
        case .edit: return "Edit Clue"
        case .finalJeopardy(let clue): return clue == nil ? "New Final Jeopardy Clue" : "Edit Final Jeopardy Clue"
        }
    }
}

struct ClueFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Fetch existing clues to extract unique categories for suggestions
    @Query private var existingClues: [Clue]
    
    let mode: ClueFormMode
    
    @State private var category = ""
    @State private var question = ""
    @State private var answer = ""
    @State private var specialClueType: SpecialClueType = .standard
    
    let pointOptions = [200, 400, 600, 800, 1000]
    private let customPointsSentinel = -1
    @State private var selectedPointOption = 200
    @State private var customPointsText = ""
    
    @State private var selectedImageData: Data?
    @State private var isImportingImage = false
    
    @State private var selectedAudioData: Data?
    @State private var isImportingAudio = false
    
    @State private var selectedVideoFileName: String?
    @State private var initialVideoFileName: String?
    @State private var isImportingVideo = false
    
    @State private var selectedAnswerImageData: Data?
    @State private var isImportingAnswerImage = false
    
    // Ability to paste from clipboard
    @State private var isTargetedImage = false
    @State private var isTargetedAudio = false
    @State private var isTargetedVideo = false
    
    init(mode: ClueFormMode) {
        self.mode = mode
    }
    
    var existingCategories: [String] {
        Array(Set(existingClues.map { $0.category })).sorted()
    }
    
    var effectivePoints: Int {
        if selectedPointOption == customPointsSentinel {
            return Int(customPointsText.trimmingCharacters(in: .whitespaces)) ?? 0
        }
        return selectedPointOption
    }
    
    var hasMedia: Bool {
        selectedImageData != nil || selectedAudioData != nil || selectedVideoFileName != nil
    }
    
    var isValid: Bool {
        let questionOK = !question.trimmingCharacters(in: .whitespaces).isEmpty
        let answerOK = !answer.trimmingCharacters(in: .whitespaces).isEmpty
        if mode.isFinalJeopardyMode {
            return questionOK && answerOK
        }
        let categoryOK = !category.trimmingCharacters(in: .whitespaces).isEmpty
        return categoryOK && questionOK && answerOK && effectivePoints > 0
    }
    
    private enum SpecialClueType: String, CaseIterable, Identifiable {
        case standard
        case dailyDouble
        case multiplePeople
        
        var id: Self { self }
        
        var title: String {
            switch self {
            case .standard: return "Standard"
            case .dailyDouble: return "Daily Double"
            case .multiplePeople: return "Multiple People"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                if !mode.isFinalJeopardyMode {
                    Section("General Info") {
                        // THE SMART FIELD:
                        // This is a TextField that suggests existing categories
                        TextField("Category", text: $category)
                            .textInputSuggestions {
                                ForEach(existingCategories, id: \.self) { cat in
                                    Text(cat).textInputCompletion(cat)
                                }
                            }
                        
                        Picker("Points", selection: $selectedPointOption) {
                            ForEach(pointOptions, id: \.self) { value in
                                Text("$\(value)").tag(value)
                            }
                            Text("Custom…").tag(customPointsSentinel)
                        }
                        
                        if selectedPointOption == customPointsSentinel {
                            TextField("Custom amount", text: $customPointsText)
#if os(iOS)
                                .keyboardType(.numberPad)
#endif
                        }
                    }
                    
                    Section("Clue Type") {
                        Picker("Type", selection: $specialClueType) {
                            ForEach(SpecialClueType.allCases) { type in
                                Text(type.title).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        if specialClueType != .standard {
                            Text("An announcement screen will appear before this clue is shown.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Section {
                        Text("This clue plays as an optional bonus round below the main board. It has no category or point value on the grid.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Media (Optional — pick one)") {
                    // 1. Image drop zone
                    MediaDropZone(isTargeted: isTargetedImage) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Button("Attach Image") { isImportingImage = true }
#if os(macOS)
                                Button("Paste") { pasteImageFromPasteboard() }
#endif
                                if selectedImageData != nil {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                    Button(role: .destructive) { selectedImageData = nil } label: {
                                        Image(systemName: "xmark.circle")
                                    }
                                    .buttonStyle(.plain)
                                }
                                Spacer()
                                Image(systemName: "photo.badge.plus")
                                    .foregroundColor(.secondary)
                            }
                            Text("Drag & drop or paste an image here")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .fileImporter(isPresented: $isImportingImage, allowedContentTypes: [.image]) { result in
                        switch result {
                        case .success(let url):
                            if url.startAccessingSecurityScopedResource() {
                                selectedImageData = try? Data(contentsOf: url)
                                url.stopAccessingSecurityScopedResource()
                            }
                        case .failure(let error):
                            print(error.localizedDescription)
                        }
                    }
                    .onDrop(of: [.image], isTargeted: $isTargetedImage, perform: handleImageProviders)
                    
                    // 2. Audio drop zone
                    MediaDropZone(isTargeted: isTargetedAudio) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Button("Attach Audio") { isImportingAudio = true }
#if os(macOS)
                                Button("Paste") { pasteAudioFromPasteboard() }
#endif
                                if selectedAudioData != nil {
                                    Image(systemName: "music.note").foregroundColor(.green)
                                    Text("Audio Added").font(.caption)
                                    Button(role: .destructive) { selectedAudioData = nil } label: {
                                        Image(systemName: "xmark.circle")
                                    }
                                    .buttonStyle(.plain)
                                }
                                Spacer()
                                Image(systemName: "waveform.badge.plus")
                                    .foregroundColor(.secondary)
                            }
                            Text("Drag & drop or paste an audio file here")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .fileImporter(
                        isPresented: $isImportingAudio,
                        allowedContentTypes: [.mp3, .wav, .audio],
                        allowsMultipleSelection: false
                    ) { result in
                        switch result {
                        case .success(let urls):
                            if let url = urls.first {
                                if url.startAccessingSecurityScopedResource() {
                                    selectedAudioData = try? Data(contentsOf: url)
                                    url.stopAccessingSecurityScopedResource()
                                }
                            }
                        case .failure(let error):
                            print(error.localizedDescription)
                        }
                    }
                    .onDrop(of: [.mp3, .wav, .audio], isTargeted: $isTargetedAudio, perform: handleAudioProviders)
                    
                    // 3. Video drop zone
                    MediaDropZone(isTargeted: isTargetedVideo) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Button("Attach Video") { isImportingVideo = true }
#if os(macOS)
                                Button("Paste") { pasteVideoFromPasteboard() }
#endif
                                if selectedVideoFileName != nil {
                                    Image(systemName: "video.fill").foregroundColor(.green)
                                    Text("Video Added").font(.caption)
                                    Button(role: .destructive) {
                                        if selectedVideoFileName != initialVideoFileName {
                                            MediaStore.deleteVideo(filename: selectedVideoFileName)
                                        }
                                        selectedVideoFileName = nil
                                    } label: {
                                        Image(systemName: "xmark.circle")
                                    }
                                    .buttonStyle(.plain)
                                }
                                Spacer()
                                Image(systemName: "video.badge.plus")
                                    .foregroundColor(.secondary)
                            }
                            Text("Drag & drop or paste a video file here")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .fileImporter(
                        isPresented: $isImportingVideo,
                        allowedContentTypes: [.movie, .video, .mpeg4Movie, .quickTimeMovie],
                        allowsMultipleSelection: false
                    ) { result in
                        switch result {
                        case .success(let urls):
                            if let url = urls.first, let filename = MediaStore.importVideo(from: url) {
                                if let old = selectedVideoFileName, old != initialVideoFileName {
                                    MediaStore.deleteVideo(filename: old)
                                }
                                selectedVideoFileName = filename
                            }
                        case .failure(let error):
                            print(error.localizedDescription)
                        }
                    }
                    .onDrop(of: [.movie, .video, .mpeg4Movie, .quickTimeMovie], isTargeted: $isTargetedVideo, perform: handleVideoProviders)
                    
                    if hasMedia {
                        Text("Only one media type is shown per clue; image takes priority, then video, then audio.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                Section("Answer Image (Optional)") {
                    HStack {
                        Button("Attach Answer Image") { isImportingAnswerImage = true }
                        if selectedAnswerImageData != nil {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            Button(role: .destructive) { selectedAnswerImageData = nil } label: {
                                Image(systemName: "xmark.circle")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .fileImporter(isPresented: $isImportingAnswerImage, allowedContentTypes: [.image]) { result in
                        switch result {
                        case .success(let url):
                            if url.startAccessingSecurityScopedResource() {
                                selectedAnswerImageData = try? Data(contentsOf: url)
                                url.stopAccessingSecurityScopedResource()
                            }
                        case .failure(let error):
                            print(error.localizedDescription)
                        }
                    }
                    Text("Shown alongside the answer text when you reveal it.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Section("Clue Details") {
                    MultilineClueField(title: "Question", text: $question)
                    MultilineClueField(title: "Answer", text: $answer)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(mode.navigationTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { cancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(mode.existingClue == nil ? "Add" : "Save") { saveClue() }
                        .disabled(!isValid)
                }
            }
            .frame(minWidth: 420, minHeight: 480)
            .onAppear(perform: populateFieldsIfNeeded)
        }
    }
    
    private func populateFieldsIfNeeded() {
        guard let clue = mode.existingClue else { return }
        category = clue.category
        question = clue.question
        answer = clue.answer
        selectedAnswerImageData = clue.answerImageData
        selectedImageData = clue.imageData
        selectedAudioData = clue.audioData
        selectedVideoFileName = clue.videoFileName
        initialVideoFileName = clue.videoFileName
        if clue.isDailyDouble {
            specialClueType = .dailyDouble
        } else if clue.isMultiplePeople {
            specialClueType = .multiplePeople
        }
        if pointOptions.contains(clue.points) {
            selectedPointOption = clue.points
        } else {
            selectedPointOption = customPointsSentinel
            customPointsText = String(clue.points)
        }
    }
    
    /// If a new video was imported (copied to disk) but the form is being
    /// cancelled, clean up the orphaned file rather than leaving it behind.
    private func cancel() {
        if selectedVideoFileName != initialVideoFileName, let leftover = selectedVideoFileName {
            MediaStore.deleteVideo(filename: leftover)
        }
        dismiss()
    }
    
    // MARK: - Drag & drop / paste loaders
    
    
    private func handleImageProviders(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.image.identifier)
        }) else { return false }
        
        provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
            guard let data else { return }
            DispatchQueue.main.async { selectedImageData = data }
        }
        return true
    }
    
    private func handleAudioProviders(_ providers: [NSItemProvider]) -> Bool {
        let audioTypes: [UTType] = [.mp3, .wav, .audio]
        guard let provider = providers.first(where: { p in
            audioTypes.contains { p.hasItemConformingToTypeIdentifier($0.identifier) }
        }), let matched = audioTypes.first(where: { provider.hasItemConformingToTypeIdentifier($0.identifier) })
        else { return false }
        
        provider.loadDataRepresentation(forTypeIdentifier: matched.identifier) { data, _ in
            guard let data else { return }
            DispatchQueue.main.async { selectedAudioData = data }
        }
        return true
    }
    
    private func handleVideoProviders(_ providers: [NSItemProvider]) -> Bool {
        let videoTypes: [UTType] = [.movie, .video, .mpeg4Movie, .quickTimeMovie]
        guard let provider = providers.first(where: { p in
            videoTypes.contains { p.hasItemConformingToTypeIdentifier($0.identifier) }
        }), let matched = videoTypes.first(where: { provider.hasItemConformingToTypeIdentifier($0.identifier) })
        else { return false }
        
        // loadFileRepresentation's temp file is deleted right after this closure
        // returns, so MediaStore has to copy it synchronously here — same
        // pattern as the existing fileImporter video handler.
        provider.loadFileRepresentation(forTypeIdentifier: matched.identifier) { url, _ in
            guard let url, let filename = MediaStore.importVideo(from: url) else { return }
            DispatchQueue.main.async {
                if let old = selectedVideoFileName, old != initialVideoFileName {
                    MediaStore.deleteVideo(filename: old)
                }
                selectedVideoFileName = filename
            }
        }
        return true
    }
    
    /// Routes a single generic paste (Cmd+V) to whichever loader matches the
    /// clipboard's actual content type.
    private func handlePaste(_ providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            _ = handleImageProviders([provider])
        } else if [UTType.movie, .video, .mpeg4Movie, .quickTimeMovie]
            .contains(where: { provider.hasItemConformingToTypeIdentifier($0.identifier) }) {
            _ = handleVideoProviders([provider])
        } else if [UTType.mp3, .wav, .audio]
            .contains(where: { provider.hasItemConformingToTypeIdentifier($0.identifier) }) {
            _ = handleAudioProviders([provider])
        }
    }
    
#if os(macOS)
    private func pasteImageFromPasteboard() {
        let pb = NSPasteboard.general
        if let images = pb.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let image = images.first,
           let tiff = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            selectedImageData = pngData
            return
        }
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], let url = urls.first {
            selectedImageData = try? Data(contentsOf: url)
        }
    }
    
    private func pasteAudioFromPasteboard() {
        let pb = NSPasteboard.general
        guard let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
              let url = urls.first else { return }
        selectedAudioData = try? Data(contentsOf: url)
    }
    
    private func pasteVideoFromPasteboard() {
        let pb = NSPasteboard.general
        guard let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
              let url = urls.first,
              let filename = MediaStore.importVideo(from: url) else { return }
        if let old = selectedVideoFileName, old != initialVideoFileName {
            MediaStore.deleteVideo(filename: old)
        }
        selectedVideoFileName = filename
    }
#endif
    
    private func saveClue() {
        let resolvedCategory = mode.isFinalJeopardyMode ? "Final Jeopardy" : category
        let resolvedPoints = mode.isFinalJeopardyMode ? 0 : effectivePoints
        
        if let clue = mode.existingClue {
            clue.category = resolvedCategory
            clue.question = question
            clue.answer = answer
            clue.points = resolvedPoints
            clue.answerImageData = selectedAnswerImageData
            clue.imageData = selectedImageData
            clue.audioData = selectedAudioData
            clue.videoFileName = selectedVideoFileName
            clue.isDailyDouble = !mode.isFinalJeopardyMode && specialClueType == .dailyDouble
            clue.isMultiplePeople = !mode.isFinalJeopardyMode && specialClueType == .multiplePeople
        } else {
            let newClue = Clue(
                category: resolvedCategory,
                question: question,
                answer: answer,
                points: resolvedPoints,
                imageData: selectedImageData,
                videoFileName: selectedVideoFileName,
                audioData: selectedAudioData,
                answerImageData: selectedAnswerImageData,
                isFinalJeopardy: mode.isFinalJeopardyMode,
                isDailyDouble: specialClueType == .dailyDouble,
                isMultiplePeople: specialClueType == .multiplePeople
            )
            modelContext.insert(newClue)
        }
        try? modelContext.save()
        dismiss()
    }
    
}

/// `TextEditor` deliberately accepts return/newline input on macOS, unlike a
/// regular `TextField`, so Hosts can create lists and multiple-choice clues.
private struct MultilineClueField: View {
    let title: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
            TextEditor(text: $text)
                .font(.body)
                .frame(minHeight: 110)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                )
        }
        .padding(.vertical, 2)
    }
}

/// Wraps a media-attach row so the *entire* row area (not just the button)
/// is a drop target, with a dashed border that highlights while something
/// draggable is hovering over it.
private struct MediaDropZone<Content: View>: View {
    let isTargeted: Bool
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        content()
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isTargeted ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        isTargeted ? Color.accentColor : Color.secondary.opacity(0.3),
                        style: StrokeStyle(lineWidth: isTargeted ? 2 : 1, dash: [5])
                    )
            )
            .animation(.easeInOut(duration: 0.15), value: isTargeted)
    }
}
