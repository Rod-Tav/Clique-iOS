//
//  InAppUploadActivityView.swift
//  Clique
//
//  Created by Assistant for in-app Live Activity display.
//

import SwiftUI
import ActivityKit

/// In-app view displaying upload progress with Live Activity data
struct InAppUploadActivityView: View {

    // MARK: - Properties

    let collectionId: String
    @Binding var showUploading: Bool
    var showNav: Bool = false
    var showRetry: Bool = false
    var retryAction: () -> Void

    @Environment(TabViewCoordinator.self) private var tabViewCoordinator
    @Environment(LiveActivityManager.self) private var liveActivityManager

    // MARK: - Body

    var body: some View {
        VStack(spacing: 12) {
            // Show custom progress UI with Live Activity data
            if let activity = liveActivityManager.currentActivity {
                customProgressView(activity: activity)
            } else {
                // Fallback if Live Activity isn't available
                fallbackProgressView
            }

            // Action buttons
            HStack(spacing: 12) {
                // Navigate to collection button
                if showNav {
                    Button {
                        showUploading = false
                        tabViewCoordinator.navigate(to: collectionId)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 14, weight: .semibold))
                            Text("View Collection")
                                .font(.callout.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.theme.cliquePink)
                        .roundCorners(12)
                    }
                }

                // Retry button
                if showRetry {
                    Button {
                        retryAction()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Retry Upload")
                                .font(.callout.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.theme.cliquePink)
                        .roundCorners(12)
                    }
                }

                Spacer()

                // Dismiss button
                if !showNav && !showRetry {
                    Button {
                        showUploading = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Custom Progress View

    /// Custom view that displays Live Activity data in-app
    @ViewBuilder
    private func customProgressView(activity: Activity<UploadActivityAttributes>) -> some View {
        VStack(spacing: 12) {
            // Header with collection name and status
            HStack(spacing: 12) {
                Image(systemName: activity.content.state.currentStatus.systemImage)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text(activity.attributes.collectionName)
                        .font(.callout.bold())
                        .textPrimary()
                        .lineLimit(1)

                    Text("\(activity.content.state.uploadedPhotos)/\(activity.attributes.totalPhotos) uploaded")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(Int(activity.content.state.totalProgress * 100))%")
                    .font(.title3.bold())
                    .textPrimary()
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.theme.surfacesBackgroundPrimary.opacity(0.3))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(progressBarColor(for: activity.content.state.currentStatus))
                        .frame(width: geometry.size.width * activity.content.state.totalProgress, height: 6)
                }
            }
            .frame(height: 6)

            // Details row (speed, ETA, filename)
            if activity.content.state.uploadSpeed != nil || activity.content.state.estimatedTimeRemaining != nil {
                HStack(spacing: 12) {
                    if let speed = activity.content.state.uploadSpeed {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 10))
                            Text(speed)
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(.secondary)
                    }

                    if let eta = activity.content.state.estimatedTimeRemaining {
                        if activity.content.state.uploadSpeed != nil {
                            Circle()
                                .fill(Color.secondary)
                                .frame(width: 2, height: 2)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 10))
                            Text(formatTimeRemaining(eta))
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
            }

            // Current filename
            if !activity.content.state.currentFileName.isEmpty {
                HStack {
                    Text(activity.content.state.currentFileName)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)

                    Spacer()
                }
            }
        }
        .padding(16)
        .primaryBackground()
        .roundCorners(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }

    /// Fallback view when Live Activity is not available
    private var fallbackProgressView: some View {
        HStack(spacing: 12) {
            CliqueProgressView(size: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text("Uploading...")
                    .font(.callout.bold())
                    .textPrimary()

                Text("Processing your photos")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .primaryBackground()
        .roundCorners(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }

    // MARK: - Helper Methods

    /// Returns the appropriate color for the progress bar based on status
    private func progressBarColor(for status: LiveActivityUploadStatus) -> Color {
        switch status {
        case .failed:
            return .red
        case .completed:
            return .green
        default:
            return .blue
        }
    }

    /// Formats time remaining in seconds to human-readable string
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
