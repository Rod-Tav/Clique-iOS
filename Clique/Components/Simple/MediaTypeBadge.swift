//
//  MediaTypeBadge.swift
//  Clique
//
//  Created by Assistant on Media type badge implementation.
//

import SwiftUI

/// Reusable badge indicating media type (Live Photo or Video).
///
/// Displays a compact badge with icon and text for videos and Live Photos.
/// Automatically determines media type from the provided image.
///
/// ## Usage
/// ```swift
/// // In a header view
/// HStack {
///     Text("Photo Title")
///     MediaTypeBadge(image: collectionImage)
/// }
/// ```
struct MediaTypeBadge: View {
    let image: CollectionImage?

    private var mediaType: MediaType? {
        guard let image = image else { return nil }

        if image.isLivePhoto {
            return .livePhoto
        } else if image.isVideo {
            return .video
        }
        return nil
    }

    var body: some View {
        if let mediaType = mediaType {
            HStack(spacing: 3) {
                Image(systemName: mediaType.iconName)
                    .font(.system(size: 8, weight: .semibold))
                Text(mediaType.displayName)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(mediaType.foregroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color(.systemGray5))
            .clipShape(.capsule)
        }
    }

    private enum MediaType {
        case livePhoto
        case video

        var iconName: String {
            switch self {
            case .livePhoto: return "livephoto"
            case .video: return "play.fill"
            }
        }

        var displayName: String {
            switch self {
            case .livePhoto: return "LIVE"
            case .video: return "VIDEO"
            }
        }

        var foregroundColor: Color {
            switch self {
            case .livePhoto: return .yellow
            case .video: return .red
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        // Live Photo badge
        HStack(spacing: 3) {
            Image(systemName: "livephoto")
                .font(.system(size: 8, weight: .semibold))
            Text("LIVE")
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(.yellow)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color(.systemGray5))
        .clipShape(.capsule)

        // Video badge
        HStack(spacing: 3) {
            Image(systemName: "play.fill")
                .font(.system(size: 8, weight: .semibold))
            Text("VIDEO")
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(.red)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color(.systemGray5))
        .clipShape(.capsule)
    }
    .padding()
    .background(Color.gray.opacity(0.3))
}
