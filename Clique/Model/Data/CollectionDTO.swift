//
//  CollectionDTO.swift
//  Clique
//
//  Created by Rod Tavangar on 1/31/25.
//  Updated by Claude on 1/31/25 for Live Photos and Videos support
//

import Foundation

func mapFromSortOption(_ sortOption: SortOption) -> Components.Schemas.SortOption {
    switch sortOption {
    case .likesAsc: return .LIKESASC
    case .likesDesc: return .LIKESDESC
    case .timeAsc: return .DATEASC
    case .timeDesc: return .DATEDESC
    }
}

// MARK: - Media Type Mapping

func mapFromMediaType(_ mediaType: MediaType) -> Components.Schemas.MediaType {
    switch mediaType {
    case .PHOTO: return .PHOTO
    case .LIVE: return .LIVE
    case .VIDEO: return .VIDEO
    }
}

func mapToMediaType(_ mediaType: Components.Schemas.MediaType) -> MediaType {
    switch mediaType {
    case .PHOTO: return .PHOTO
    case .LIVE: return .LIVE
    case .VIDEO: return .VIDEO
    }
}

// MARK: - Upload Status Mapping

func mapToUploadStatus(_ status: Components.Schemas.UploadStatus) -> UploadStatus {
    switch status {
    case .PENDING: return .PENDING
    case .FAILED: return .FAILED
    case .COMPLETED: return .COMPLETED
    }
}

// MARK: - Photo/Video Date Mapping

func mapToPhotoVideoDate(photo: Components.Schemas.PhotoDataNoPath?, video: Components.Schemas.VideoDataNoPath?, mediaType: MediaType, date: Date) -> Components.Schemas.PhotoVideoDate {
    return Components.Schemas.PhotoVideoDate(
        photo: photo,
        video: video,
        mediaType: mapFromMediaType(mediaType),
        dateCreated: convertFromDate(date)
    )
}

/// Legacy function - will be removed after full migration
func mapToPhotoDatePair(photo: Components.Schemas.PhotoDataNoPath?, date: Date) -> Components.Schemas.PhotoVideoDate {
    return Components.Schemas.PhotoVideoDate(photo: photo, video: nil, mediaType: .PHOTO, dateCreated: convertFromDate(date))
}

// MARK: - Collection Image Mapping

func mapToCollectionImage(_ data: Components.Schemas.UrlCollectionItem) -> CollectionImage {
    // Parse date and extract timezone offset if present in the date string
    let dateResult = convertToDateWithTimezone(data.collectionItem!.dateCreated!)
    let date = dateResult?.date ?? Date()
    let timezoneOffset = dateResult?.offset  // Extracted from date string if present

    return CollectionImage(
        id: data.collectionItem!.collectionItemId!,
        owner: mapToUser(data.collectionItem!.user!),
        imageUrl: data.urls != nil ? mapToMediaUrls(data.urls!) : nil,
        videoUrls: data.videoUrls != nil ? mapToMediaUrls(data.videoUrls!) : nil,
        videoId: data.collectionItem!.videoId,
        mediaType: data.collectionItem!.mediaType != nil ? mapToMediaType(data.collectionItem!.mediaType!) : .PHOTO,
        uploadStatus: data.collectionItem!.uploadStatus != nil ? mapToUploadStatus(data.collectionItem!.uploadStatus!) : nil,
        date: date,
        numLikes: data.collectionItem!.likes!,
        numComments: data.collectionItem!.commentCount ?? 0,
        numTaggedMembers: 0,
        hasLiked: data.isLiked ?? false,
        cachedTimezoneOffset: timezoneOffset  // Store timezone offset extracted from date string
    )
}


func mapToCollection(_ data: Components.Schemas.Collection) -> ClCollection {
    return mapToCollection(collectionData: data.collectionData!, images: data.collectionItems?.map { mapToCollectionImage($0) } ?? [])
}

func mapToCollection(collectionData: Components.Schemas.CollectionData, images: [CollectionImage]) -> ClCollection {
    return ClCollection(
        id: collectionData.collectionDataId!,
        name: collectionData.name == "" ? "Untitled Collection" : collectionData.name!,
        description: collectionData.description!,
        userId: collectionData.createdBy!,
        cliqueId: collectionData.clique!,
        creation: convertToDate(collectionData.dateCreated),
        images: images,
        coverPhoto: collectionData.coverPhoto == nil ? nil : mapToMediaUrls(collectionData.coverPhoto!),
        visibility: mapToVisibility(collectionData.privacySetting!),
        numFlicks: collectionData.picCount!
    )
}

func mapToCollection(_ data: Components.Schemas.CollectionResponseBody) -> ClCollection {
    return mapToCollection(data.collection!)
}

func mapToCollections(_ data: Components.Schemas.GetCollectionsResponseBody) -> [ClCollection] {
    let collections = data.collections!
    return collections.map { mapToCollection($0) }
}
