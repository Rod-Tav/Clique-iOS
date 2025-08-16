//
//  AlbumThumbnail.swift
//  Clique
//
//  Created by Rod Tavangar on 8/15/25.
//

import SwiftUI
import Photos

/// Displays a thumbnail for a photo album with title and count.
struct AlbumThumbnail: View {
    /// Album data containing collection, title, count, and optional thumbnail
    let album: (collection: PHAssetCollection, title: String, count: Int, thumbnail: UIImage?)
    
    var body: some View {
        VStack(spacing: 8) {
            if let thumbnail = album.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(120)
                    .clipped()
                    .roundCorners(8)
            } else {
                loadingView
            }
            
            VStack(spacing: 2) {
                Text(album.title)
                    .font(.caption)
                    .textPrimary()
                    .lineLimit(1)
                
                Text("\(album.count)")
                    .font(.caption2)
                    .textSecondary()
            }
            .width(120)
        }
    }
    
    /// Loading placeholder when thumbnail is not available
    private var loadingView: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .frame(120)
            .roundCorners(8)
            .overlay(
                ProgressView()
                    .scaleEffect(0.5)
            )
    }
}
