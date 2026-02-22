//
//  ExtensionRootView.swift
//  CliqueMessages
//
//  Root view for the Clique iMessage extension
//

import SwiftUI
import Messages
import CliqueCore

/// Root view for the Clique iMessage extension
///
/// This view manages the top-level routing and presentation logic for the extension.
/// It handles authentication state, presentation styles (compact vs expanded), and
/// navigation between different screens.
///
/// ## View Hierarchy
/// - Unauthenticated: Shows `NotAuthenticatedView`
/// - Compact mode: Shows `CompactContentView`
/// - Expanded mode: Shows content based on `navigationState`:
///   - `.cliqueList` → `CliqueListView`
///   - `.collectionList` → `CollectionListView`
///   - `.flickGrid` → `FlickGridView`
///   - `.createClique` → `CreateCliqueView`
///
/// ## Usage Example
/// ```swift
/// ExtensionRootView(viewModel: extensionViewModel)
/// ```
struct ExtensionRootView: View {

    // MARK: - Properties

    @Bindable var viewModel: ExtensionViewModel

    /// Closure to request expansion from compact to expanded mode (unused but kept for compatibility)
    var onRequestExpand: (() -> Void)?

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background color
            Color.extensionBackground
                .ignoresSafeArea()

            // Content - always show clique list
            if !viewModel.isAuthenticated {
                NotAuthenticatedView()
            } else {
                mainContent
            }
        }
        .environment(viewModel)
    }

    // MARK: - Main Content

    private var mainContent: some View {
        Group {
            if viewModel.isLoading && viewModel.cliques.isEmpty {
                loadingView
            } else if let errorMessage = viewModel.errorMessage, viewModel.cliques.isEmpty {
                errorView(errorMessage)
            } else {
                navigationContent
            }
        }
    }

    @ViewBuilder
    private var navigationContent: some View {
        switch viewModel.navigationState {
        case .cliqueList:
            CliqueListView()
        case .collectionList:
            CollectionListView()
        case .flickGrid:
            FlickGridView(viewModel: viewModel) { flick in
                viewModel.sendFlick(flick)
            }
        case .createClique:
            // Not implemented in extension - just show clique list
            CliqueListView()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(Color.cliquePink)

            Text("Loading...")
                .font(.system(size: 15))
                .foregroundStyle(Color.extensionSecondaryText)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.orange)

            Text("Something went wrong")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.extensionPrimaryText)

            Text(message)
                .font(.system(size: 15))
                .foregroundStyle(Color.extensionSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}

// MARK: - Not Authenticated View

/// View shown when the user is not authenticated
///
/// Prompts the user to open the main Clique app to sign in.
struct NotAuthenticatedView: View {
    var body: some View {
        VStack(spacing: 24) {
            // Clique logo or icon
            Image(systemName: "person.2.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.cliquePink)

            VStack(spacing: 12) {
                Text("Sign in Required")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.extensionPrimaryText)

                Text("Please open the Clique app to sign in, then return here to share photos with your cliques.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.extensionSecondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Note: App extensions cannot directly open the main app
            // Users need to tap the Clique app icon to sign in
            Text("Tap the Clique app icon below to open Clique and sign in")
                .font(.caption)
                .foregroundStyle(Color.extensionSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)
                .padding(.top, 8)
        }
    }
}

