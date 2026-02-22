//
//  SharedAlbumPhoto.swift
//  Clique
//
//  Wraps a PHAsset + cached thumbnail into a DisplayablePhoto.
//

import Photos
import UIKit

/// Wraps a PHAsset and its cached thumbnail for display in the unified photo grid.
@available(iOS 26, *)
struct SharedAlbumPhoto: DisplayablePhoto {
    let asset: PHAsset
    let thumbnail: UIImage?

    var id: String { asset.localIdentifier }
    var creationDate: Date? { asset.creationDate }
    var isVideo: Bool { asset.mediaType == .video }
    var isLivePhoto: Bool { asset.mediaSubtypes.contains(.photoLive) }
    var mediaUrls: MediaUrls? { nil }
    var localThumbnail: UIImage? { thumbnail }
    var hasSocialFeatures: Bool { false }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: SharedAlbumPhoto, rhs: SharedAlbumPhoto) -> Bool {
        lhs.id == rhs.id
    }
}
