//
//  CollectionListView.swift
//  CliqueMessages
//
//  Displays a list of collections for the selected clique
//

import SwiftUI


struct CollectionListView: View {
    @Environment(ExtensionViewModel.self) var viewModel

    var body: some View {
        VStack(spacing: 0) {
            header

            if viewModel.isLoading {
                loadingState
            } else if viewModel.collectionsForClique.isEmpty {
                emptyState
            } else {
                collectionList
            }
        }
        .background(Color.extensionBackground)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            // Back button
            Button {
                viewModel.navigateBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.cliquePink)
            }
            .padding(.leading, 16)

            Spacer()

            VStack(spacing: 4) {
                if let clique = viewModel.selectedClique {
                    Text("Collections in \(clique.name)")
                        .font(.headline)
                        .foregroundStyle(Color.extensionPrimaryText)

                    Text("\(viewModel.collectionsForClique.count) collection\(viewModel.collectionsForClique.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(Color.extensionSecondaryText)
                }
            }

            Spacer()

            // Spacer for symmetry
            Color.clear
                .frame(width: 40)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color.extensionBackground)
    }

    // MARK: - Collection List

    private var collectionList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(viewModel.collectionsForClique) { collection in
                    collectionRow(collection)
                        .contentShape(.rect)
                        .onTapGesture {
                            viewModel.selectCollection(collection)
                        }
                }
            }
        }
    }

    private func collectionRow(_ collection: CachedCollection) -> some View {
        HStack(spacing: 12) {
            // Cover Photo
            ExtensionThumbnailView(urlString: collection.thumbUrl, type: .collectionRow)

            // Collection Info
            VStack(alignment: .leading, spacing: 4) {
                Text(collection.name)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Color.extensionPrimaryText)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text("\(collection.flickCount) flick\(collection.flickCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(Color.extensionSecondaryText)

                    Text("•")
                        .font(.caption)
                        .foregroundStyle(Color.extensionSecondaryText)

                    Text(formatDate(collection.createdAt))
                        .font(.caption)
                        .foregroundStyle(Color.extensionSecondaryText)
                }
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Color.extensionSecondaryText.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.extensionBackground)
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(Color.cliquePink)
            Text("Loading collections...")
                .font(.caption)
                .foregroundStyle(Color.extensionSecondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 48))
                .foregroundStyle(Color.extensionSecondaryText.opacity(0.5))

            Text("No Collections")
                .font(.headline)
                .foregroundStyle(Color.extensionPrimaryText)

            Text("This clique doesn't have any collections yet")
                .font(.caption)
                .foregroundStyle(Color.extensionSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helper Methods

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
