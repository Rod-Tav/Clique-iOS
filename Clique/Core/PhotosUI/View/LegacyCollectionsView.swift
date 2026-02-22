//
//  LegacyCollectionsView.swift
//  Clique
//
//  Legacy tab: browse Clique backend collections and migrate them to iCloud.
//

import SwiftUI
import Kingfisher

@available(iOS 26, *)
struct LegacyCollectionsView: View {
    @Environment(UserStore.self) var userStore
    @Environment(CollectionStore.self) var collectionStore
    @Environment(CollectionImageStore.self) var collectionImageStore

    @State var collections: [ClCollection] = []
    @State var isLoading: Bool = true
    @State var errorMessage: String?
    @State var migrationHelper = PhotoMigrationHelper()
    @State var migratingCollectionId: String?

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            content
        }
        .navigationTitle("Legacy")
        .toolbarTitleDisplayMode(.large)
        .task {
            await fetchCollections()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isLoading {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(0..<6, id: \.self) { _ in
                    placeholderCard
                }
            }
            .padding(16)
        } else if collections.isEmpty {
            emptyState
        } else {
            Text("Migration functions coming soon")
                .font(.subheadline)
                .foregroundStyle(Color.theme.textSecondary)
                .padding(.horizontal, 16)
                .padding(.top, 8)

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(collections) { collection in
                    collectionCard(collection)
                }
            }
            .padding(16)
            .navigationDestination(for: ClCollection.self) { collection in
                CollectionMainView(
                    collectionId: collection.id,
                    cliqueId: collection.cliqueId,
                    collectionStore,
                    collectionImageStore
                )
                .navigationBarBackButtonHidden()
            }
        }

        // Migration progress overlay
        if migrationHelper.isMigrating {
            migrationOverlay
        }
    }

    // MARK: - Collection Card

    private func collectionCard(_ collection: ClCollection) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Cover photo
            NavigationLink(value: collection) {
                coverImage(for: collection)
            }
            .buttonStyle(.plain)

            // Name
            Text(collection.name)
                .font(.subheadline.weight(.medium))
                .textPrimary()
                .lineLimit(1)

            // Photo count
            Text("\(collection.numFlicks) photos")
                .font(.caption)
                .foregroundStyle(Color.theme.textSecondary)

            // Migrate button
            migrateButton(for: collection)
        }
    }

    @ViewBuilder
    private func coverImage(for collection: ClCollection) -> some View {
        if let coverUrl = collection.coverPhoto?.bestUrl ?? collection.images.first?.imageUrl?.bestUrl {
            KFImage(coverUrl)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 160)
                .clipped()
                .roundCorners(12)
        } else {
            ZStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.15))
                Image(systemName: "photo.stack")
                    .font(.title2)
                    .foregroundStyle(Color.theme.textSecondary)
            }
            .frame(height: 160)
            .roundCorners(12)
        }
    }

    private func migrateButton(for collection: ClCollection) -> some View {
        Button {
            Task {
                migratingCollectionId = collection.id
                await migrationHelper.migrateCollection(collection, albumName: collection.name)
                migratingCollectionId = nil
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "icloud.and.arrow.up")
                    .font(.caption2)
                Text("Migrate")
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(migratingCollectionId == collection.id ? Color.theme.textSecondary : .blue)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.1))
            .roundCorners(6)
        }
        .disabled(migrationHelper.isMigrating)
    }

    // MARK: - States

    private var placeholderCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Rectangle()
                .fill(Color.gray.opacity(0.15))
                .frame(height: 160)
                .roundCorners(12)
                .shimmer()

            Rectangle()
                .fill(Color.gray.opacity(0.15))
                .frame(width: 80, height: 14)
                .roundCorners(4)

            Rectangle()
                .fill(Color.gray.opacity(0.15))
                .frame(width: 50, height: 12)
                .roundCorners(4)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.largeTitle)
                .foregroundStyle(Color.theme.textSecondary)

            Text("No legacy collections found.")
                .font(.subheadline)
                .foregroundStyle(Color.theme.textSecondary)
                .multilineTextAlignment(.center)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }

    private var migrationOverlay: some View {
        VStack(spacing: 12) {
            ProgressView(value: migrationHelper.migrationProgress)
                .progressViewStyle(.linear)
                .tint(.blue)

            Text("Migrating \(migrationHelper.migratedCount)/\(migrationHelper.totalCount)")
                .font(.caption)
                .foregroundStyle(Color.theme.textSecondary)

            if let error = migrationHelper.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .roundCorners(12)
        .padding(.horizontal, 32)
    }

    // MARK: - Data Fetching

    func fetchCollections() async {
        guard let userId = userStore.currentUserId else {
            await MainActor.run {
                isLoading = false
                errorMessage = "Not signed in."
            }
            return
        }

        do {
            let fetched = try await CollectionService.getCollectionsByUser(
                .init(path: .init(userId: userId), query: .init(page: 0, size: 50))
            )

            await MainActor.run {
                collections = fetched
                isLoading = false

                // Also update CollectionStore so navigation to CollectionMainView works
                for collection in fetched {
                    collectionStore.updateCollection(collection, collectionImageStore)
                }
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
