//
//  DisplayablePhoto.swift
//  Clique
//
//  Unified protocol for displaying photos from different sources
//  (iCloud PHAssets and Clique backend CollectionImages).
//

import UIKit
import Photos

/// A unified protocol for displaying photos from different sources.
protocol DisplayablePhoto: Identifiable, Hashable {
    var id: String { get }
    var creationDate: Date? { get }
    var isVideo: Bool { get }
    var isLivePhoto: Bool { get }

    /// URL-based images (Clique backend) - nil for local photos
    var mediaUrls: MediaUrls? { get }

    /// Local thumbnail image (PHAsset) - nil for URL-based photos
    var localThumbnail: UIImage? { get }

    /// Whether this photo supports social features (likes, comments, tags)
    var hasSocialFeatures: Bool { get }
}
