//
//  MediaAttachmentSection.swift
//  Jeopardy
//
//  Created by Gusti Sandyaga Putra Wardhana on 16/09/26.
//


//
//  MediaAttachmentSection.swift
//  Jeopardy
//
//  Lives in Views/ClueCard/Edit/. The "Media (Optional)" section of the
//  clue editor — file picker, drag & drop, clipboard paste, and the
//  crop-sheet trigger for images. Split out of ClueEditorView.swift,
//  which also held the layout shell and the multiple-choice editing
//  section in the same 688-line file — see PROJECT.md's architecture map.
//
//  Takes bindings straight into the two ClueDraft fields this subsystem
//  actually touches (`media`, `answerImageData`) rather than the whole
//  draft. All the import-flow state that used to live on ClueEditorView
//  (isCropping, pendingOriginalImageData, initialVideoFilename, the error
//  message, etc.) moves in here too, since nothing outside this
//  subsystem ever read it — it's genuinely local now, not just
//  relocated.
//

import SwiftUI
internal import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

struct MediaAttachmentSection: View {
    @Binding var media: MediaAttachment
    @Binding var answerImageData: Data?
    let isShowingHelp: Bool

    @State private var isImportingMedia = false
    @State private var isTargetedMedia = false
    @State private var mediaErrorMessage: String?
    @State private var isCropping = false
    @State private var pendingOriginalImageData: Data?
    @State private var alsoUseFullAsAnswerImage = false
    /// The clue's already-persisted video filename (if any) at the moment
    /// this section appeared. Used so a fresh import that later gets
    /// replaced/cleared can be safely deleted from disk without ever
    /// deleting the clue's existing, still-in-use video.
    @State private var initialVideoFilename: String?

    var body: some View {
        SectionContainer(
            title: "Media (Optional)",
            help: "Attach at most one image, audio clip, or video — whichever fits this clue. Drag & drop, paste, or use Attach Media.",
            isShowingHelp: isShowingHelp
        ) {
            MediaDropZone(isTargeted: isTargetedMedia) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Button("Attach Media") { isImportingMedia = true }
                        #if os(macOS)
                        Button("Paste") { pasteMediaFromPasteboard() }
                        #endif
                        if !media.isNone {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            if case .image = media {
                                Button("Re-crop") {
                                    pendingOriginalImageData = answerImageData ?? currentImageData()
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
        .onAppear {
            if case .video(let filename) = media {
                initialVideoFilename = filename
            }
        }
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
    }

    private var mediaIcon: String {
        switch media {
        case .none: return "paperclip.badge.ellipsis"
        case .image: return "photo.fill"
        case .audio: return "waveform"
        case .video: return "video.fill"
        }
    }

    private var mediaStatusText: String {
        switch media {
        case .none: return "Drag & drop, paste, or attach an image, audio, or video file."
        case .image: return "Image attached."
        case .audio: return "Audio attached."
        case .video: return "Video attached."
        }
    }

    private func currentImageData() -> Data? {
        if case .image(let data) = media { return data }
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
    /// of the whole editor (see ClueEditorView.cancelTapped()).
    private func replaceMedia(with new: MediaAttachment) {
        if case .video(let filename) = media, filename != initialVideoFilename {
            MediaStore.deleteVideo(filename: filename)
        }
        media = new
        if case .image = new {} else { answerImageData = nil }
    }

    /// (#9 Error recognition/recovery) Every failure path here sets
    /// `mediaErrorMessage` — none of them silently no-op the way the old
    /// `try?`-based importers did.
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
                    media = .image(croppedData)
                    answerImageData = alsoUseFullAsAnswerImage ? pendingOriginalImageData : nil
                    isCropping = false
                },
                onUseFullImage: { fullData in
                    media = .image(fullData)
                    answerImageData = alsoUseFullAsAnswerImage ? pendingOriginalImageData : nil
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