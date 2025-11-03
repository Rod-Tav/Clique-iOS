//
//  CliqueUploadActivityWidgetLiveActivity.swift
//  CliqueUploadActivityWidget
//
//  Created by Rod Tavangar on 11/2/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

/// Live Activity widget for displaying photo upload progress
///
/// This widget provides real-time upload progress updates in the Dynamic Island
/// and on the Lock Screen. It displays upload status, progress percentage, photo count,
/// and estimated time remaining.
///
/// ## Features
/// - **Dynamic Island**: Compact view with progress, expanded view with details
/// - **Lock Screen**: Full progress bar with upload information
/// - **Real-time Updates**: Progress updates as photos upload
/// - **Deep Linking**: Tap to navigate to collection
///
/// ## Integration
/// Uses `UploadActivityAttributes` for static data and `ContentState` for dynamic updates.
/// Managed by `LiveActivityManager` in the main app.
struct CliqueUploadActivityWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: UploadActivityAttributes.self) { context in
            // Lock Screen / Banner UI
            LockScreenUploadView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // MARK: - Expanded View (Long Press)

                DynamicIslandExpandedRegion(.center) {
                    ExpandedCenterView(context: context)
                }

                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeadingView(context: context)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailingView(context: context)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(context: context)
                }
            } compactLeading: {
                // MARK: - Compact Leading (Left Side)
                CompactLeadingView(context: context)
            } compactTrailing: {
                // MARK: - Compact Trailing (Right Side)
                CompactTrailingView(context: context)
            } minimal: {
                // MARK: - Minimal (Multiple Activities)
                MinimalView(context: context)
            }
        }
    }
}

// MARK: - Lock Screen View

/// Lock Screen view displaying comprehensive upload progress
struct LockScreenUploadView: View {
    let context: ActivityViewContext<UploadActivityAttributes>

    var body: some View {
        VStack(spacing: 12) {
            // Header with icon and status
            HStack(spacing: 12) {
                Image(systemName: context.state.currentStatus.systemImage)
                    .font(.system(size: 20))
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Uploading to \(context.attributes.collectionName)")
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)

                    Text(context.state.currentStatus.displayText)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(Int(context.state.totalProgress * 100))%")
                    .font(.system(size: 18, weight: .bold))
                    .contentTransition(.numericText())
            }

            // Progress bar
            ProgressView(value: context.state.totalProgress)
                .tint(.blue)

            // Details row
            HStack {
                Text("\(context.state.uploadedPhotos) of \(context.attributes.totalPhotos) photos")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                Spacer()

                if let eta = context.state.estimatedTimeRemaining {
                    Text("\(formatTimeRemaining(eta)) left")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .activityBackgroundTint(.black.opacity(0.2))
    }

    private func formatTimeRemaining(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)s"
        } else if seconds < 3600 {
            return "\(seconds / 60)m"
        } else {
            return "\(seconds / 3600)h"
        }
    }
}

// MARK: - Preview

#Preview("Live Activity", as: .dynamicIsland(.compact), using: UploadActivityAttributes(
    collectionName: "Beach Trip 2025",
    totalPhotos: 10,
    cliqueId: "clique-123"
)) {
    CliqueUploadActivityWidgetLiveActivity()
} contentStates: {
    UploadActivityAttributes.ContentState(
        uploadedPhotos: 3,
        totalProgress: 0.3,
        currentStatus: .uploading,
        currentFileName: "IMG_1234.HEIC",
        uploadSpeed: "2.5 MB/s",
        estimatedTimeRemaining: 120
    )

    UploadActivityAttributes.ContentState(
        uploadedPhotos: 7,
        totalProgress: 0.7,
        currentStatus: .uploading,
        currentFileName: "IMG_5678.HEIC",
        uploadSpeed: "3.1 MB/s",
        estimatedTimeRemaining: 45
    )

    UploadActivityAttributes.ContentState(
        uploadedPhotos: 10,
        totalProgress: 1.0,
        currentStatus: .completed,
        currentFileName: "",
        uploadSpeed: nil,
        estimatedTimeRemaining: nil
    )
}
