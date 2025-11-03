//
//  PHAsset+Extensions.swift
//  Clique
//
//  Created by Assistant on PHAsset convenience extensions.
//

import Photos

extension PHAsset {
    /// Whether this asset is a video
    var isVideo: Bool {
        mediaType == .video
    }

    /// Whether this asset is a Live Photo
    var isLivePhoto: Bool {
        mediaSubtypes.contains(.photoLive)
    }

    /// Video duration formatted as string (e.g., "1:23")
    /// Returns nil for non-video assets
    var formattedDuration: String? {
        guard isVideo else { return nil }
        let duration = Int(self.duration)
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
