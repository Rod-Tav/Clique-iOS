//
//  CollectionErrorStateView.swift
//  Clique
//
//  Created by Claude Code
//

import SwiftUI

/// Reusable error state view for collection-related errors
///
/// This component provides a consistent error screen layout with:
/// - Icon, title, and message
/// - Optional retry button
/// - Go back button
struct CollectionErrorStateView: View {
    @Environment(\.dismiss) private var dismiss

    let iconName: String
    let title: String
    let message: String
    var retryAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            Image(systemName: iconName)
                .font(.system(size: 80))
                .foregroundStyle(Color.theme.textSecondary)

            // Title
            Text(title)
                .font(.title2.bold())
                .textPrimary()

            // Message
            Text(message)
                .font(.body)
                .textSecondary()
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            // Retry Button (if provided)
            if let retryAction = retryAction {
                CliqueButton(
                    type: .primary,
                    text: "Retry",
                    fullWidth: true
                ) {
                    retryAction()
                }
                .padding(.horizontal, 24)
            }

            // Dismiss Button
            CliqueButton(
                type: retryAction == nil ? .primary : .secondary,
                text: "Go Back",
                fullWidth: true
            ) {
                dismiss()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .bottomTabBarPadding()
        .primaryBackground()
    }
}

#Preview("Access Denied") {
    NavigationStack {
        CollectionErrorStateView(
            iconName: "lock.circle.fill",
            title: "No Access",
            message: "You don't have access to this collection"
        )
    }
}

#Preview("Not Found") {
    NavigationStack {
        CollectionErrorStateView(
            iconName: "photo.on.rectangle.angled",
            title: "Collection Not Found",
            message: "This collection doesn't exist or may have been deleted"
        )
    }
}

#Preview("Network Error") {
    NavigationStack {
        CollectionErrorStateView(
            iconName: "exclamationmark.triangle.fill",
            title: "Unable to Load Collection",
            message: "There was a problem loading this collection. Please check your connection and try again.",
            retryAction: {
                print("Retry tapped")
            }
        )
    }
}
