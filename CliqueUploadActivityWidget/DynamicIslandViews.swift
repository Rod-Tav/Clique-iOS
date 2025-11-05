//
//  DynamicIslandViews.swift
//  CliqueUploadActivityWidget
//
//  Created by Claude Code on 11/2/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Compact Views

/// Compact leading view showing upload icon
struct CompactLeadingView: View {
    let context: ActivityViewContext<UploadActivityAttributes>

    var body: some View {
        Image(systemName: context.state.currentStatus.systemImage)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color.cliquePink)
    }
}

/// Compact trailing view showing progress percentage
struct CompactTrailingView: View {
    let context: ActivityViewContext<UploadActivityAttributes>

    var body: some View {
        Text("\(Int(context.state.totalProgress * 100))%")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.primary)
            .contentTransition(.numericText())
    }
}

// MARK: - Minimal View

/// Minimal view showing just the upload icon
struct MinimalView: View {
    let context: ActivityViewContext<UploadActivityAttributes>

    var body: some View {
        Image(systemName: context.state.currentStatus.systemImage)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.cliquePink)
    }
}

// MARK: - Expanded Views

/// Expanded center view showing primary upload information
struct ExpandedCenterView: View {
    let context: ActivityViewContext<UploadActivityAttributes>

    var body: some View {
        VStack(spacing: 4) {
            Text(context.attributes.collectionName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text("\(context.state.uploadedPhotos)/\(context.attributes.totalPhotos) uploaded")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }
}

/// Expanded leading view showing status icon
struct ExpandedLeadingView: View {
    let context: ActivityViewContext<UploadActivityAttributes>

    var body: some View {
        Image(systemName: context.state.currentStatus.systemImage)
            .font(.system(size: 24, weight: .semibold))
            .foregroundStyle(Color.cliquePink)
    }
}

/// Expanded trailing view showing progress percentage
struct ExpandedTrailingView: View {
    let context: ActivityViewContext<UploadActivityAttributes>

    var body: some View {
        VStack(spacing: 2) {
            Text("\(Int(context.state.totalProgress * 100))%")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())

            Text(context.state.currentStatus.displayText)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
}

/// Expanded bottom view showing progress bar and optional details
struct ExpandedBottomView: View {
    let context: ActivityViewContext<UploadActivityAttributes>

    /// Color for progress bar based on upload status
    private var progressBarColor: Color {
        switch context.state.currentStatus {
        case .failed:
            return .red
        case .completed:
            return Color.cliquePink
        default:
            return Color.cliquePink
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.quaternary)
                        .frame(height: 6)

                    // Progress (pink for uploading, red for failed, pink for completed)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(progressBarColor)
                        .frame(width: geometry.size.width * context.state.totalProgress, height: 6)
                }
            }
            .frame(height: 6)

            // Optional details row
            if let speed = context.state.uploadSpeed,
               let eta = context.state.estimatedTimeRemaining {
                HStack(spacing: 12) {
                    // Upload speed
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 10))
                        Text(speed)
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(.secondary)

                    // Divider
                    Circle()
                        .fill(.secondary)
                        .frame(width: 2, height: 2)

                    // Time remaining
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10))
                        Text(formatTimeRemaining(eta))
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(.secondary)

                    Spacer()
                }
            }

            // Current file name (if available and not empty)
            if !context.state.currentFileName.isEmpty {
                HStack {
                    Text(context.state.currentFileName)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)

                    Spacer()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    /// Format time remaining in seconds to human-readable string
    private func formatTimeRemaining(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)s"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes)m"
        } else {
            let hours = seconds / 3600
            let minutes = (seconds % 3600) / 60
            return "\(hours)h \(minutes)m"
        }
    }
}

