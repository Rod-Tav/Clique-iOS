//
//  AppGroupManager.swift
//  CliqueMessages
//
//  Manages App Group container access for shared data between the main app and extensions.
//

import Foundation

final class AppGroupManager {
    static let shared = AppGroupManager()

    private static let appGroupIdentifier = "group.com.cliquellc.clique"

    private init() {}

    /// The App Group container URL, if available.
    var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier)
    }

    /// Directory for cached thumbnails inside the App Group container.
    var thumbnailsDirectory: URL? {
        containerURL?.appendingPathComponent("thumbnails", isDirectory: true)
    }

    /// Creates the thumbnails directory if it doesn't already exist.
    func ensureThumbnailsDirectoryExists() {
        guard let dir = thumbnailsDirectory else { return }
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
}
