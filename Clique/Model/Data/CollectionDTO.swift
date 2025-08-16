//
//  CollectionDTO.swift
//  Clique
//
//  Created by Rod Tavangar on 1/31/25.
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

func mapToPhotoDatePair(photo: Components.Schemas.PhotoDataNoPath?, date: Date) -> Components.Schemas.PhotoDatePair {
    return Components.Schemas.PhotoDatePair(photo: photo, dateCreated: convertFromDate(date))
}

func mapToCollectionImage(_ data: Components.Schemas.UrlCollectionItem) -> CollectionImage {
    return CollectionImage(
        id: data.collectionItem!.collectionItemId!,
        owner: mapToUser(data.collectionItem!.user!),
        imageUrl: mapToPhotoUrls(data.urls!),
        date: convertToDate(data.collectionItem!.dateCreated!),
        numLikes: data.collectionItem!.likes!,
        numComments: data.collectionItem!.commentCount ?? 0,
        numTaggedMembers: 0,
        hasLiked: data.isLiked ?? false
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
        coverPhoto: collectionData.coverPhoto == nil ? nil : mapToPhotoUrls(collectionData.coverPhoto!),
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
