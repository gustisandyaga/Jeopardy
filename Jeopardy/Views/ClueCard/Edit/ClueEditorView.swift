//
//  ClueEditorView.swift
//  Jeopardy
//
//  The shared editing surface used both inline inside ClueDetailView (when
//  editing an existing clue) and by AddClueScreen (when creating a new
//  one). Operates purely on a ClueDraft binding — the caller decides what
//  Save/Cancel actually do (write to a live Clue vs. insert a new one).
//
//  Heuristic notes (see PROJECT.md's "Clue Editor Redesign" addenda for
//  the full write-up):
//   - #1 Visibility of system status  -> statusBanner (mode + Cmd+S hint)
//   - #3 User control and freedom     -> Cmd+Z undo stack; the back
//                                         chevron (NOT a separate Cancel
//                                         button) routes through the
//                                         caller's discard/save
//                                         confirmation when dirty
//   - #6 Recognition rather than recall -> reused by ClueDetailView in place
//   - #9 Error recognition/recovery   -> media import failures surface an
//                                         alert instead of silently no-op'ing
//   - #10 Help and documentation      -> per-section captions toggled by
//                                         the "?" toolbar button
//   - Gestalt common region/proximity -> sectionContainer(...) gives each
//                                         conceptual group its own visible
//                                         boundary instead of relying on
//                                         whitespace alone; the body is
//                                         further split into a "setup"
//                                         column and a "content" column
//                                         (see body / setupColumn /
//                                         contentColumn below) so related
//                                         sections sit next to each other
//                                         instead of every section
//                                         stretching the full window width
//   - WCAG 1.4.10 Reflow              -> the 2-column split only applies
//                                         when there's room for it
//                                         (ViewThatFits); narrow windows
//                                         fall back to the original single
//                                         column instead of clipping
//   - WCAG-adjacent (click-away)      -> tapping empty space drops focus,
//                                         same pattern as PlayerView's
//                                         name field
//

import SwiftUI
import SwiftData
internal import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

struct ClueEditorView: View {
    @Binding var draft: ClueDraft
    let isFinalJeopardyMode: Bool
    let isNewClue: Bool
    let existingCategories: [String]
    let onSave: () -> Void
    /// Called when the Host backs out. The caller (ClueDetailView /
    /// AddClueScreen) owns the actual dirty-check + confirmation dialog —
    /// this view never deletes anything on the Host's behalf before that
    /// decision is made (see cancelTapped()).
    let onCancel: () -> Void

    @FocusState private var focusedField: ClueEditField?
    @State private var isShowingHelp = false

    @State private var isImportingMedia = false
    @State private var isTargetedMedia = false
    @State private var mediaErrorMessage: String?
    @State private var isCropping = false
    @State private var pendingOriginalImageData: Data?
    @State private var alsoUseFullAsAnswerImage = false
    @State private var initialVideoFilename: String?

    @State private var undoStack: [ClueDraft] = []
    @State private var isApplyingUndo = false

    private let pointOptions = [200, 400, 600, 800, 1000]

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    statusBanner
                    
                    // Adaptive 2-column layout: try the wide 2-column split
                    // first, fall back to the original single-column stack
                    // when the available width can't fit both columns at
                    // their minimum width. See setupColumn/contentColumn below
                    // for the actual grouping.
                    
                    if proxy.size.width >= 700 {
                        twoColumnLayout
                    } else {
                        singleColumnLayout
                    }
                    
                }
                .padding(24)
                // (#3 / click-away-to-unfocus) Tapping any non-interactive area
                // drops keyboard focus — same pattern PlayerView already uses
                // for its name field. Buttons/fields still consume their own
                // taps normally; this only catches taps that land on empty
                // space between them.
                .contentShape(Rectangle())
                .onTapGesture { focusedField = nil }
            }
        }
        .frame(minWidth: 480, minHeight: 560)
        .onAppear {
            if case .video(let filename) = draft.media {
                initialVideoFilename = filename
            }
        }
        .onChange(of: draft) { oldValue, _ in
            guard !isApplyingUndo else { return }
            undoStack.append(oldValue)
            if undoStack.count > 50 { undoStack.removeFirst() }
        }
        .background(
            Group {
                Button("Undo") { undo() }
                    .keyboardShortcut("z", modifiers: .command)
                Button(isNewClue ? "Add" : "Save") { save() }
                    .keyboardShortcut("s", modifiers: .command)
            }
            .hidden()
        )
        .alert(
            "Couldn't Attach File",
            isPresented: Binding(
                get: { mediaErrorMessage != nil },
                set: { if !$0 { mediaErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { mediaErrorMessage = nil }
        } message: {
            Text(mediaErrorMessage ?? "")
        }
        .sheet(isPresented: $isCropping) { cropSheet }
        // NOTE: hides the system-provided back chevron so the single
        // custom one below (.navigation placement) is the only back/cancel
        // affordance — see file header. This modifier's cross-platform
        // behavior on a macOS-hosted NavigationStack hasn't been confirmed
        // in a real Xcode build; verify the native chevron is actually
        // gone (not just visually duplicated) before relying on this.
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    cancelTapped()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("Back")
                .help(isNewClue ? "Discard this new clue" : "Back (will ask before discarding unsaved changes)")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isNewClue ? "Add" : "Save") { save() }
                    .disabled(!draft.isValid(isFinalJeopardy: isFinalJeopardyMode))
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    isShowingHelp.toggle()
                } label: {
                    Image(systemName: isShowingHelp ? "questionmark.circle.fill" : "questionmark.circle")
                }
                .help("Show or hide a plain-language explanation of each section")
            }
        }
    }

    // MARK: - Adaptive layout (2-column setup/content split)

    /// "Setup" — how this clue behaves: category/points/type, plus
    /// Multiple Choice (still a configuration decision, even though its
    /// option list can grow long).
    private var setupColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !isFinalJeopardyMode {
                generalSection
                typeSection
            } else {
                sectionContainer(
                    title: "Final Jeopardy",
                    help: "This clue plays as an optional bonus round below the main board. It has no category or point value on the grid."
                ) {
                    EmptyView()
                }
            }
            multipleChoiceSection
        }
    }

    /// "Content" — what this clue actually shows/asks: the attached media
    /// and the question/answer text itself.
    private var contentColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            mediaSection
            questionAnswerSection
        }
    }

    /// Preferred layout when there's enough width: setup on the left,
    /// content on the right, each with a sane minimum before either
    /// column gets uncomfortably cramped.
    private var twoColumnLayout: some View {
        HStack(alignment: .top, spacing: 20) {
            setupColumn.frame(minWidth: 340, maxWidth: .infinity, alignment: .top)
            contentColumn.frame(minWidth: 340, maxWidth: .infinity, alignment: .top)
        }
    }

    /// Fallback for narrow widths (resized macOS window, iPhone/iPad
    /// portrait) — the original stacked order, so nothing clips or
    /// requires horizontal scrolling (WCAG 1.4.10 Reflow).
    private var singleColumnLayout: some View {
        VStack(alignment: .leading, spacing: 16) {
            setupColumn
            contentColumn
        }
    }

    // MARK: - Status banner (#1 Visibility of system status)

    private var statusBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: isNewClue ? "plus.circle.fill" : "pencil.circle.fill")
            VStack(alignment: .leading, spacing: 2) {
                Text(isNewClue ? "Creating New Clue" : "Editing Clue")
                    .font(.headline)
                Text("Press ⌘S to save")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(Color.accentColor.opacity(0.15))
        .cornerRadius(8)
    }

    // MARK: - General info

    private var generalSection: some View {
        sectionContainer(
            title: "General Info",
            help: "The category groups this clue into a column on the board. Points is what it's worth when answered correctly."
        ) {
            TextField("Category", text: $draft.category)
                .focused($focusedField, equals: .category)
                .textInputSuggestions {
                    ForEach(existingCategories, id: \.self) { cat in
                        Text(cat).textInputCompletion(cat)
                    }
                }

            Picker("Points", selection: pointsBinding) {
                ForEach(pointOptions, id: \.self) { value in
                    Text("$\(value)").tag(value)
                }
                Text("Custom…").tag(-1)
            }

            if draft.isCustomPoints {
                TextField("Custom amount", text: $draft.customPointsText)
                    .focused($focusedField, equals: .customPoints)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
            }
        }
    }

    private var pointsBinding: Binding<Int> {
        Binding(
            get: { draft.isCustomPoints ? -1 : draft.points },
            set: { newValue in
                if newValue == -1 {
                    draft.isCustomPoints = true
                } else {
                    draft.isCustomPoints = false
                    draft.points = newValue
                }
            }
        )
    }

    // MARK: - Clue type

    private var typeSection: some View {
        sectionContainer(
            title: "Clue Type",
            help: "Daily Double and Multiple People show a full-screen announcement before this clue is revealed. Multiple Choice is set up separately below and can be combined with either."
        ) {
            Picker("Type", selection: $draft.kind) {
                ForEach(ClueKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Multiple choice

    private var multipleChoiceSection: some View {
        sectionContainer(
            title: "Multiple Choice (Optional)",
            help: "Turn this on to give tappable answer options instead of, or alongside, free text. Needs at least 2 filled-in options."
        ) {
            Toggle("Enable multiple choice", isOn: $draft.isMultipleChoice)

            if draft.isMultipleChoice {
                ForEach(draft.choiceOptions.indices, id: \.self) { idx in
                    HStack {
                        Text(choiceLetter(for: idx))
                            .font(.headline)
                            .frame(width: 20)
                        TextField("Option \(choiceLetter(for: idx))", text: $draft.choiceOptions[idx])
                            .focused($focusedField, equals: .choiceOption(idx))
                        if draft.choiceOptions.count > 2 {
                            Button(role: .destructive) { removeOption(at: idx) } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.plain)
                            .help("Remove this option")
                        }
                    }
                }

                Button {
                    draft.choiceOptions.append("")
                } label: {
                    Label("Add Option", systemImage: "plus.circle")
                }
                .disabled(draft.choiceOptions.count >= 8)

                Picker("Correct Answer", selection: $draft.correctChoiceIndex) {
                    ForEach(draft.choiceOptions.indices, id: \.self) { idx in
                        if !draft.choiceOptions[idx].trimmingCharacters(in: .whitespaces).isEmpty {
                            Text(choiceLetter(for: idx)).tag(idx)
                        }
                    }
                }
            }
        }
    }

    private func removeOption(at index: Int) {
        guard draft.choiceOptions.count > 2 else { return }
        draft.choiceOptions.remove(at: index)
        if draft.correctChoiceIndex == index {
            draft.correctChoiceIndex = 0
        } else if draft.correctChoiceIndex > index {
            draft.correctChoiceIndex -= 1
        }
    }

    // MARK: - Media (unified image/audio/video)

    private var mediaSection: some View {
        sectionContainer(
            title: "Media (Optional)",
            help: "Attach at most one image, audio clip, or video — whichever fits this clue. Drag & drop, paste, or use Attach Media."
        ) {
            MediaDropZone(isTargeted: isTargetedMedia) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Button("Attach Media") { isImportingMedia = true }
                        #if os(macOS)
                        Button("Paste") { pasteMediaFromPasteboard() }
                        #endif
                        if !draft.media.isNone {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            if case .image = draft.media {
                                Button("Re-crop") {
                                    pendingOriginalImageData = draft.answerImageData ?? currentImageData()
                                    isCropping = true
                                }
                            }
                            Button(role: .destructive) { clearMedia() } label: {
                                Image(systemName: "xmark.circle")
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                        Image(systemName: mediaIcon).foregroundColor(.secondary)
                    }
                    Text(mediaStatusText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .fileImporter(
                isPresented: $isImportingMedia,
                allowedContentTypes: [.image, .movie, .video, .mpeg4Movie, .quickTimeMovie, .mp3, .wav, .audio],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first { importMedia(from: url) }
                case .failure(let error):
                    mediaErrorMessage = error.localizedDescription
                }
            }
            .onDrop(
                of: [.image, .movie, .video, .mpeg4Movie, .quickTimeMovie, .mp3, .wav, .audio],
                isTargeted: $isTargetedMedia,
                perform: handleDropProviders
            )
        }
    }

    private var mediaIcon: String {
        switch draft.media {
        case .none: return "paperclip.badge.ellipsis"
        case .image: return "photo.fill"
        case .audio: return "waveform"
        case .video: return "video.fill"
        }
    }

    private var mediaStatusText: String {
        switch draft.media {
        case .none: return "Drag & drop, paste, or attach an image, audio, or video file."
        case .image: return "Image attached."
        case .audio: return "Audio attached."
        case .video: return "Video attached."
        }
    }

    private func currentImageData() -> Data? {
        if case .image(let data) = draft.media { return data }
        return nil
    }

    private func clearMedia() {
        replaceMedia(with: .none)
    }

    /// Deletes a freshly-imported video from disk when it's being replaced
    /// or cleared — but only if it isn't the clue's already-persisted
    /// video (tracked via `initialVideoFilename`), same care the old
    /// ClueFormView took to avoid orphaning files. This is a REPLACEMENT,
    /// not a cancel — it's safe to delete immediately here because the
    /// Host has already made a new, different choice, unlike backing out
    /// of the whole editor (see cancelTapped()).
    private func replaceMedia(with new: MediaAttachment) {
        if case .video(let filename) = draft.media, filename != initialVideoFilename {
            MediaStore.deleteVideo(filename: filename)
        }
        draft.media = new
        if case .image = new {} else { draft.answerImageData = nil }
    }

    /// (#9) Every failure path here sets `mediaErrorMessage` — none of them
    /// silently no-op the way the old `try?`-based importers did.
    private func importMedia(from url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        let type = UTType(filenameExtension: url.pathExtension)

        if let type, type.conforms(to: .image) {
            guard let data = try? Data(contentsOf: url) else {
                mediaErrorMessage = "\"\(url.lastPathComponent)\" couldn't be read as an image."
                return
            }
            replaceMedia(with: .none)
            pendingOriginalImageData = data
            isCropping = true
        } else if let type, type.conforms(to: .movie) || type.conforms(to: .video) {
            guard let filename = MediaStore.importVideo(from: url) else {
                mediaErrorMessage = "\"\(url.lastPathComponent)\" couldn't be imported as a video."
                return
            }
            replaceMedia(with: .video(filename: filename))
        } else if let type, type.conforms(to: .audio) {
            guard let data = try? Data(contentsOf: url) else {
                mediaErrorMessage = "\"\(url.lastPathComponent)\" couldn't be read as an audio file."
                return
            }
            replaceMedia(with: .audio(data))
        } else {
            mediaErrorMessage = "\"\(url.lastPathComponent)\" isn't a supported image, audio, or video file."
        }
    }

    private func handleDropProviders(_ providers: [NSItemProvider]) -> Bool {
        let imageTypes: [UTType] = [.image]
        let videoTypes: [UTType] = [.movie, .video, .mpeg4Movie, .quickTimeMovie]
        let audioTypes: [UTType] = [.mp3, .wav, .audio]

        guard let provider = providers.first else { return false }

        if let matched = imageTypes.first(where: { provider.hasItemConformingToTypeIdentifier($0.identifier) }) {
            provider.loadDataRepresentation(forTypeIdentifier: matched.identifier) { data, _ in
                DispatchQueue.main.async {
                    guard let data else {
                        mediaErrorMessage = "That image couldn't be read."
                        return
                    }
                    replaceMedia(with: .none)
                    pendingOriginalImageData = data
                    isCropping = true
                }
            }
            return true
        } else if let matched = videoTypes.first(where: { provider.hasItemConformingToTypeIdentifier($0.identifier) }) {
            provider.loadFileRepresentation(forTypeIdentifier: matched.identifier) { url, _ in
                DispatchQueue.main.async {
                    guard let url, let filename = MediaStore.importVideo(from: url) else {
                        mediaErrorMessage = "That video couldn't be imported."
                        return
                    }
                    replaceMedia(with: .video(filename: filename))
                }
            }
            return true
        } else if let matched = audioTypes.first(where: { provider.hasItemConformingToTypeIdentifier($0.identifier) }) {
            provider.loadDataRepresentation(forTypeIdentifier: matched.identifier) { data, _ in
                DispatchQueue.main.async {
                    guard let data else {
                        mediaErrorMessage = "That audio file couldn't be read."
                        return
                    }
                    replaceMedia(with: .audio(data))
                }
            }
            return true
        }

        mediaErrorMessage = "That file type isn't supported for clue media."
        return false
    }

    #if os(macOS)
    private func pasteMediaFromPasteboard() {
        let pb = NSPasteboard.general
        if let images = pb.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let image = images.first, let pngData = image.pngData() {
            replaceMedia(with: .none)
            pendingOriginalImageData = pngData
            isCropping = true
            return
        }
        guard let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], let url = urls.first else {
            mediaErrorMessage = "Nothing on the clipboard looks like an image, audio, or video file."
            return
        }
        importMedia(from: url)
    }
    #endif

    @ViewBuilder
    private var cropSheet: some View {
        if let pendingOriginalImageData, let nsImage = NSImage(data: pendingOriginalImageData) {
            ImageCropView(
                originalImage: nsImage,
                alsoUseFullAsAnswerImage: $alsoUseFullAsAnswerImage,
                onCrop: { croppedData in
                    draft.media = .image(croppedData)
                    draft.answerImageData = alsoUseFullAsAnswerImage ? pendingOriginalImageData : nil
                    isCropping = false
                },
                onUseFullImage: { fullData in
                    draft.media = .image(fullData)
                    draft.answerImageData = alsoUseFullAsAnswerImage ? pendingOriginalImageData : nil
                    isCropping = false
                },
                onCancel: { isCropping = false }
            )
        } else {
            VStack(spacing: 12) {
                Text("Couldn't load this image for cropping.").font(.headline)
                Button("Close") { isCropping = false }
            }
            .padding()
            .frame(width: 360, height: 160)
        }
    }

    // MARK: - Question / Answer

    private var questionAnswerSection: some View {
        sectionContainer(title: "Clue Details", help: "The Question is what the Host reads aloud; the Answer (or multiple-choice options above) is what's revealed after.") {
            MultilineClueField(title: "Question", text: $draft.question, focus: $focusedField, field: .question)
            MultilineClueField(
                title: draft.hasValidMultipleChoiceAnswer ? "Answer (optional — multiple choice is set)" : "Answer",
                text: $draft.answer,
                focus: $focusedField,
                field: .answer
            )
        }
    }

    // MARK: - Section container (Gestalt: common region)

    @ViewBuilder
    private func sectionContainer<Content: View>(
        title: String,
        help: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
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

    // MARK: - Undo / Save / Cancel

    private func undo() {
        guard let previous = undoStack.popLast() else { return }
        isApplyingUndo = true
        draft = previous
        isApplyingUndo = false
    }

    private func save() {
        focusedField = nil
        guard draft.isValid(isFinalJeopardy: isFinalJeopardyMode) else { return }
        onSave()
    }

    /// Fires from the single back-chevron button. Deliberately does NOT
    /// delete anything here — the caller's onCancel decides whether this
    /// is a clean exit or needs a Save/Discard/Keep Editing prompt first,
    /// and any video cleanup only happens once "Discard" is the Host's
    /// actual, confirmed choice (see ClueDetailView.discardEdits /
    /// AddClueScreen's discard path). Deleting the file before that
    /// decision was a real bug in the previous version: if the Host had
    /// picked "Save Changes" from the resulting dialog, the video would
    /// already be gone from disk by the time save ran.
    private func cancelTapped() {
        onCancel()
    }
}

/// `TextEditor` deliberately accepts return/newline input, unlike a plain
/// `TextField`, so multi-line lists and multiple-choice-style answers can
/// still be typed into a free-text Question/Answer.
private struct MultilineClueField: View {
    let title: String
    @Binding var text: String
    var focus: FocusState<ClueEditField?>.Binding
    var field: ClueEditField

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline)
            TextEditor(text: $text)
                .focused(focus, equals: field)
                .font(.body)
                .frame(minHeight: 110)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.25), lineWidth: 1))
        }
        .padding(.vertical, 2)
    }
}

/// Wraps a media-attach row so the *entire* row area is a drop target,
/// with a dashed border that highlights while something draggable hovers.
private struct MediaDropZone<Content: View>: View {
    let isTargeted: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(isTargeted ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.06)))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isTargeted ? Color.accentColor : Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: isTargeted ? 2 : 1, dash: [5]))
            )
            .animation(.easeInOut(duration: 0.15), value: isTargeted)
    }
}
