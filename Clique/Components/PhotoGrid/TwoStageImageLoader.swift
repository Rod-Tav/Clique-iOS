//
//  TwoStageImageLoader.swift
//  Clique
//
//  Created by Assistant on 8/29/25.
//
//  Two-stage image loader that shows thumbnail immediately 
//  and loads full resolution in background

import SwiftUI
import Photos

/// Loads images in two stages: thumbnail first, then full resolution
struct TwoStageImageLoader: View {
    let asset: PHAsset
    let thumbnail: UIImage?
    let contentMode: ContentMode

    @State private var fullImage: UIImage?
    @State private var isLoadingFull = false
    @State private var requestID: PHImageRequestID?

    init(
        asset: PHAsset,
        thumbnail: UIImage?,
        contentMode: ContentMode = .fit
    ) {
        self.asset = asset
        self.thumbnail = thumbnail
        self.contentMode = contentMode
    }
    
    var body: some View {
        ZStack {
            // Stage 1: Immediate thumbnail display
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .opacity(fullImage == nil ? 1 : 0)
            } else if fullImage == nil {
                // Fallback loading view if no thumbnail
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            }

            // Stage 2: Full resolution overlay with smooth transition
            if let fullImage = fullImage {
                Image(uiImage: fullImage)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity.animation(.easeIn(duration: 0.2)))
            }
        }
        .onAppear {
            loadFullResolution()
        }
        .onDisappear {
            cancelRequest()
        }
    }
    
    private func loadFullResolution() {
        guard fullImage == nil && !isLoadingFull else { return }
        isLoadingFull = true

        let options = PHImageRequestOptions()
        options.version = .current
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        options.resizeMode = .none  // Prevents iOS green tint bug with PHImageManagerMaximumSize

        // Request full resolution image
        requestID = PHImageManager.default().requestImage(
            for: asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit,
            options: options
        ) { image, info in
            // Check if this is the final, high-quality image
            if let image = image,
               let info = info,
               !(info[PHImageResultIsDegradedKey] as? Bool ?? false) {
                DispatchQueue.main.async {
                    withAnimation(.easeIn(duration: 0.2)) {
                        self.fullImage = image
                    }
                    self.isLoadingFull = false
                }
            }
        }
    }
    
    private func cancelRequest() {
        if let requestID = requestID {
            PHImageManager.default().cancelImageRequest(requestID)
        }
    }
}