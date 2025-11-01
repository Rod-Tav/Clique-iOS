//
//  CollectionPreviewStatsView.swift
//  Clique
//
//  Created by Rod Tavangar on 12/11/24.
//

import SwiftUI

struct CollectionPreviewStatsView: View {
    let likes: Int
    let comments: Int
    let hasLiked: Bool
    let isLivePhoto: Bool
    let isVideo: Bool
    let videoDuration: TimeInterval?
    let videoUrl: URL?
    let compact: Bool

    @State private var fetchedDuration: TimeInterval?

    var displayDuration: TimeInterval? {
        videoDuration ?? fetchedDuration
    }

    init(likes: Int, comments: Int, hasLiked: Bool, isLivePhoto: Bool, isVideo: Bool, videoDuration: TimeInterval?, videoUrl: URL?, compact: Bool = false) {
        self.likes = likes
        self.comments = comments
        self.hasLiked = hasLiked
        self.isLivePhoto = isLivePhoto
        self.isVideo = isVideo
        self.videoDuration = videoDuration
        self.videoUrl = videoUrl
        self.compact = compact
    }

    var body: some View {
        HStack(spacing: 4) {
            // Likes
            HStack(spacing: 2) {
                IconImage("heart-filled", color: hasLiked ? .theme.red : .theme.white, size: 12)

                Text(formatNumber(likes))
                    .font(.caption2.bold())
                    .foregroundStyle(Color.theme.white)
                    .fixedSize()
            }

            // Comments
            HStack(spacing: 2) {
                IconImage("comment-filled", color: .theme.white, size: 12)

                Text(formatNumber(comments))
                    .font(.caption2.bold())
                    .foregroundStyle(Color.theme.white)
                    .fixedSize()
            }

            // Media type badge
            if isLivePhoto {
                Spacer()
                
                // Live Photo: white icon
                Image(systemName: "livephoto")
                    .font(.caption2.bold())
                    .foregroundStyle(Color.theme.white)
            } else if isVideo {
                Spacer()
                
                if compact {
                    // Compact mode: show only duration text
                    if let duration = displayDuration {
                        Text(VideoDurationHelper.formatDuration(duration))
                            .font(.caption2.bold())
                            .foregroundStyle(Color.theme.white)
                            .lineLimit(1)
                            .fixedSize()
                    }
                } else {
                    // Normal mode: show play icon + duration
                    HStack(spacing: 3) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.theme.white)

                        if let duration = displayDuration {
                            Text(VideoDurationHelper.formatDuration(duration))
                                .font(.caption2.bold())
                                .foregroundStyle(Color.theme.white)
                                .fixedSize()
                        }
                    }
                }
            }
        }
        .lineLimit(1)
        .padding(.leading, 4)
        .padding(.trailing, 4)
        .padding(.bottom, 3)
        .background(Gradients.feedCellCommentBg)
        .task {
            // Fetch duration if not already available
            if isVideo, videoDuration == nil, let url = videoUrl {
                fetchedDuration = await VideoDurationHelper.getDuration(from: url)
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        // Regular photo
        Rectangle()
            .fill(.blue)
            .frame(width: 150, height: 150)
            .overlay(alignment: .bottomLeading) {
                CollectionPreviewStatsView(likes: 2, comments: 20, hasLiked: false, isLivePhoto: false, isVideo: false, videoDuration: nil, videoUrl: nil)
            }

        // Live photo
        Rectangle()
            .fill(.green)
            .frame(width: 150, height: 150)
            .overlay(alignment: .bottomLeading) {
                CollectionPreviewStatsView(likes: 15, comments: 5, hasLiked: true, isLivePhoto: true, isVideo: false, videoDuration: nil, videoUrl: nil)
            }

        // Video with duration
        Rectangle()
            .fill(.purple)
            .frame(width: 150, height: 150)
            .overlay(alignment: .bottomLeading) {
                CollectionPreviewStatsView(likes: 100, comments: 42, hasLiked: false, isLivePhoto: false, isVideo: true, videoDuration: 125.5, videoUrl: nil)
            }
    }
    .padding()
}
