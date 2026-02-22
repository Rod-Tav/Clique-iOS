//
//  ClCollection.swift
//  Clique
//
//  Created by Rod Tavangar on 6/27/24.
//

import SwiftUI
import PhotosUI

enum UploadStatus: String, Codable {
    case PENDING
    case FAILED
    case COMPLETED
}

struct CollectionImage: Identifiable, Hashable, Codable {
    let id: String
    var owner: User?

    // PHOTO component (always present for PHOTO and LIVE types)
    var imageUrl: MediaUrls? = nil
    var uiImage: UIImage? = nil

    // VIDEO component (present for LIVE and VIDEO types)
    var videoUrls: MediaUrls? = nil
    var videoId: String? = nil
    var videoDuration: TimeInterval? = nil

    // Media type indicator
    var mediaType: MediaType = .PHOTO

    // Upload/processing status
    var uploadStatus: UploadStatus? = nil

    var date: Date
    var numLikes: Int = 0
    var numComments: Int = 0
    var numTaggedMembers: Int = 0
    var hasLiked: Bool = false

    // Timezone offset cached from video metadata (not persisted, runtime only)
    // Format: "-0400", "+0530", etc.
    // This is extracted from video file metadata to display dates in original timezone
    var cachedTimezoneOffset: String? = nil

    // Computed properties
    var isLivePhoto: Bool {
        mediaType == .LIVE
    }

    var isVideo: Bool {
        mediaType == .VIDEO
    }

    var hasVideoComponent: Bool {
        videoUrls != nil
    }
}

extension CollectionImage {
    enum CodingKeys: String, CodingKey {
        case id, owner, imageUrl, videoUrls, videoId, videoDuration, mediaType, uploadStatus
        case date, numLikes, numComments, numTaggedMembers, hasLiked
        // intentionally exclude `uiImage` and `cachedTimezoneOffset` (runtime only)
    }
}

// MARK: - DisplayablePhoto Conformance

extension CollectionImage: DisplayablePhoto {
    var creationDate: Date? { date }
    var mediaUrls: MediaUrls? { imageUrl }
    var localThumbnail: UIImage? { uiImage }
    var hasSocialFeatures: Bool { true }
}

struct ClCollection: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var description: String = ""
    var userId: String = ""
    var cliqueId: String = ""
    let creation: Date
    var images: [CollectionImage]
    var coverPhoto: MediaUrls? = nil
    var visibility: Visibility
    var numFlicks: Int = 0

    var mostLikedImage: String?

    // Computed properties for media types
    var hasLivePhotos: Bool {
        images.contains { $0.mediaType == .LIVE }
    }

    var hasVideos: Bool {
        images.contains { $0.mediaType == .VIDEO }
    }

    var mediaTypeCounts: (photos: Int, livePhotos: Int, videos: Int) {
        let photos = images.filter { $0.mediaType == .PHOTO }.count
        let livePhotos = images.filter { $0.mediaType == .LIVE }.count
        let videos = images.filter { $0.mediaType == .VIDEO }.count
        return (photos, livePhotos, videos)
    }

    /// Returns the display flick count including the current user's pending uploads.
    /// Uses the backend numFlicks count as the base and adds any pending uploads by the current user for optimistic UI.
    /// - Parameter currentUserId: The ID of the currently authenticated user
    /// - Returns: Total flick count including current user's pending uploads
    func displayFlickCount(currentUserId: String?) -> Int {
        // Count current user's pending uploads (optimistic UI)
        let pendingCount: Int
        if let currentUserId {
            pendingCount = images.filter {
                $0.uploadStatus == .PENDING && $0.owner?.id == currentUserId
            }.count
        } else {
            pendingCount = 0
        }

        let displayCount = numFlicks + pendingCount

        // Special check: if we're about to show 0 but we have images locally, do a final fallback check
        if displayCount == 0 && !images.isEmpty {
            // Count all non-failed images as a fallback (includes pending, completed, or status-less)
            let nonFailedImages = images.filter { $0.uploadStatus != .FAILED }.count
            if nonFailedImages > 0 {
                return nonFailedImages
            }
        }

        return displayCount
    }
}

extension ClCollection {
    static var MOCK_COLLECTIONS: [ClCollection] = [
        .init(id: "1", name: "Trip to New York", description: "A trip to New York City", creation: createDate(year: 2021, month: 8, day: 4), images: collectionUrls(cliqueName: "huddle", number: 1, max: 192), coverPhoto: MediaUrls(url: "huddle-cl-1-cover"), visibility: .pub),
        .init(id: "2", name: "Fun in the snow", description: "So much fun in the snow!", creation: createDate(year: 2022, month: 1, day: 29), images: collectionUrls(cliqueName: "t_olympics", number: 1, max: 96), coverPhoto: MediaUrls(url: "t_olympics-cl-1-cover"), visibility: .followers),
        .init(id: "3", name: "Vintage Flicks", description: "these are the best and hardest and toughest flicks from what we called my 20th birthday. tuff photos incthese are the best and hardest and toughest flicks from what we called my 20th birthday. tuff photos nice",creation: createDate(year: 2023, month: 9, day: 25), images: collectionUrls(cliqueName: "t_olympics", number: 2, max: 45), coverPhoto: MediaUrls(url: "t_olympics-cl-2-cover"), visibility: .priv)
    ]

    static func collectionUrls(cliqueName: String, number: Int, max: Int) -> [CollectionImage] {
        var images: [CollectionImage] = []
        for i in 1 ... max {
            let name = "\(cliqueName)-cl-\(number)-\(i)"
            images.append(CollectionImage(id: UUID().uuidString, imageUrl: MediaUrls(url: name), date: Date(timeIntervalSinceNow: Double(i * 50000))))
        }

        return images
    }
    
    static func createDate(year: Int, month: Int, day: Int) -> Date {
        let dateComponents = DateComponents(year: year, month: month, day: day)
        let calendar = Calendar.current
        return calendar.date(from: dateComponents)!
    }
}
