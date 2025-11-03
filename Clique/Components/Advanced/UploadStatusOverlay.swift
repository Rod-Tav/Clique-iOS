//
//  UploadStatusOverlay.swift
//  Clique
//
//  Created by Assistant on 1/31/25.
//

import SwiftUI

/// Overlay component that displays upload/processing status for collection images.
///
/// Shows clear visual feedback for items that are:
/// - PENDING: Currently being processed by backend (tap to refresh and check status)
/// - FAILED: Upload or processing failed, may offer retry
/// - COMPLETED: No overlay shown
struct UploadStatusOverlay: View {
    let status: UploadStatus?
    var onRetry: (() -> Void)?
    var onRefresh: (() -> Void)?

    var body: some View {
        Group {
            switch status {
            case .PENDING:
                processingOverlay
            case .FAILED:
                failedOverlay
            case .COMPLETED, .none:
                EmptyView()
            }
        }
    }

    private var processingOverlay: some View {
        ZStack {
            // Semi-transparent dark overlay
            Color.black.opacity(0.50)

            if let onRefresh = onRefresh {
                // Make the entire overlay a button for proper visual feedback
                Button {
                    onRefresh()
                } label: {
                    VStack(spacing: 8) {
                        // Processing text
                        Text("Processing")
                            .font(.callout.weight(.semibold))
                            .foregroundColor(.white)

                        // Tap to refresh instruction
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))

                            Text("Tap to refresh")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    .contentShape(.rect) // Make entire VStack tappable
                }
                .buttonStyle(.plain) // No default button styling
            } else {
                VStack(spacing: 8) {
                    // Processing text
                    Text("Processing")
                        .font(.callout.weight(.semibold))
                        .foregroundColor(.white)
                }
            }
        }
    }

    private var failedOverlay: some View {
        ZStack {
            // Red-tinted overlay to indicate error
            Color.red.opacity(0.3)

            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundColor(.white)

                Text("Failed")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.white)

                if let onRetry = onRetry {
                    Button("Retry") {
                        onRetry()
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    .controlSize(.small)
                }
            }
        }
    }
}
