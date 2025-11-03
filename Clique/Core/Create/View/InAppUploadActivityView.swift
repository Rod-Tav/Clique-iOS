//
//  InAppUploadActivityView.swift
//  Clique
//
//  Created by Assistant for in-app Live Activity display.
//

import SwiftUI
import ActivityKit

/// In-app view displaying the Live Activity UI with retry/navigation functionality
struct InAppUploadActivityView: View {

    // MARK: - Properties

    let collectionId: String
    @Binding var showUploading: Bool
    var showNav: Bool = false
    var showRetry: Bool = false
    var retryAction: () -> Void

    @Environment(TabViewCoordinator.self) private var tabViewCoordinator

    // MARK: - Body

    var body: some View {
        VStack(spacing: 12) {
            // Show Live Activity UI if available
            if let activity = LiveActivityManager.shared.currentActivity {
                ActivityView(activity: activity)
                    .frame(height: 100)
                    .roundCorners(16)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            } else {
                // Fallback if Live Activity isn't available (shouldn't happen)
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
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
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
}
