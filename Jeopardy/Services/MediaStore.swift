//
//  MediaStore.swift
//  Jeopardy
//
//  Copies host-selected video files into the app's own Application Support
//  folder so they keep working after the security-scoped fileImporter access
//  ends and across future launches. Only the resulting filename is stored on
//  the Clue model (see Clue.videoFileName); this type resolves that filename
//  back to a full URL.
//

import Foundation

enum MediaStore {
    static var videosDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Jeopardy/Videos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func url(for filename: String) -> URL {
        videosDirectory.appendingPathComponent(filename)
    }

    /// Copies the video at `sourceURL` (typically from a fileImporter result)
    /// into the app's media folder and returns the new filename, or nil on failure.
    @discardableResult
    static func importVideo(from sourceURL: URL) -> String? {
        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer { if didAccess { sourceURL.stopAccessingSecurityScopedResource() } }

        let ext = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension
        let filename = UUID().uuidString + "." + ext
        let destination = videosDirectory.appendingPathComponent(filename)

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destination)
            return filename
        } catch {
            print("MediaStore: failed to import video — \(error.localizedDescription)")
            return nil
        }
    }

    /// Writes raw video bytes (e.g. decoded from a board-save file) as a new
    /// managed video file and returns the resulting filename.
    static func writeVideoData(_ data: Data, fileExtension: String) -> String? {
        let ext = fileExtension.isEmpty ? "mov" : fileExtension
        let filename = UUID().uuidString + "." + ext
        let destination = videosDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: destination)
            return filename
        } catch {
            print("MediaStore: failed to write video data — \(error.localizedDescription)")
            return nil
        }
    }

    static func deleteVideo(filename: String?) {
        guard let filename else { return }
        let url = videosDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }
}
