//
//  SharedAlbumsListView.swift
//  Clique
//
//  Albums tab: grid of shared album covers with drill-in navigation.
//

import SwiftUI
import Photos
import MessageUI

@available(iOS 26, *)
struct SharedAlbumsListView: View {
    @Environment(SharedAlbumsData.self) var sharedData
    @Environment(SharedAlbumActivityStore.self) var activityStore
    @Environment(CloudCliquesStore.self) var cloudCliquesStore
    @Environment(UserStore.self) var userStore

    @State var activityChanges: [AlbumActivityChange] = []
    @State var isCreatingClique: Bool = false
    @State var showMessageCompose: Bool = false
    @State var createdCliqueId: String? = nil

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ScrollView(.vertical) {
            VStack {
                activityWidget

                cloudCliquesSection

                albumGrid
            }
        }
        .sheet(isPresented: $showMessageCompose) {
            if MFMessageComposeViewController.canSendText() {
                CliqueMessageComposer(recipients: [], body: createCliqueMessageBody)
            }
        }
        .navigationTitle("Collections")
        .toolbarTitleDisplayMode(.large)
        .task {
            await loadAlbumsIfNeeded()
        }
    }

    @ViewBuilder private var activityWidget: some View {
        if sharedData.isLoadingAlbums {
            EmptyView()
        } else if !activityStore.hasBaseline {
//            noBaselineCard
        } else if !activityChanges.isEmpty {
            activityCarousel
        }
    }

    private var noBaselineCard: some View {
        Button {
            if let url = URL(string: "sms://") {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "message.fill")
                    .font(.title2)
                    .foregroundStyle(Color.theme.buttonCTA)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Make something happen")
                        .font(.subheadline.weight(.semibold))
                        .textPrimary()

                    Text("Share photos with friends through iMessage")
                        .font(.caption)
                        .foregroundStyle(Color.theme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.theme.textSecondary)
            }
            .padding(14)
            .background(Color.theme.surfacesElevatedPrimary)
            .roundCorners(12)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var activityCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(activityChanges, id: \.albumLocalIdentifier) { change in
                    activityCard(change)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 8)
    }

    private func activityCard(_ change: AlbumActivityChange) -> some View {
        let album = sharedData.sharedAlbums.first { $0.collection.localIdentifier == change.albumLocalIdentifier }

        return NavigationLink(value: album?.collection) {
            HStack(spacing: 10) {
                if let thumbnail = album?.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 48, height: 48)
                        .clipped()
                        .roundCorners(8)
                } else {
                    ZStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.15))
                        Image(systemName: "photo.stack")
                            .font(.caption)
                            .foregroundStyle(Color.theme.textSecondary)
                    }
                    .frame(width: 48, height: 48)
                    .roundCorners(8)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(change.albumTitle)
                        .font(.caption.weight(.semibold))
                        .textPrimary()
                        .lineLimit(1)

                    if let clique = cloudCliquesStore.cliqueForAlbum(title: change.albumTitle) {
                        Text(clique.cliqueName)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Color.theme.buttonCTA)
                    }

                    Text("+\(change.delta) new photos")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.theme.buttonCTA)

                    Text("since \(change.lastSeenDate.formatted(.dateTime.month(.abbreviated).day()))")
                        .font(.caption2)
                        .foregroundStyle(Color.theme.textSecondary)
                }
            }
            .padding(10)
            .background(Color.theme.surfacesElevatedPrimary)
            .roundCorners(12)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var albumGrid: some View {
        if sharedData.isLoadingAlbums {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(0..<6, id: \.self) { _ in
                    albumPlaceholder
                }
            }
            .padding(16)
        } else if sharedData.sharedAlbums.isEmpty {
            emptyState
        } else {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(sharedData.sharedAlbums.indices, id: \.self) { index in
                    let album = sharedData.sharedAlbums[index]
                    NavigationLink(value: album.collection) {
                        albumCard(album)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .navigationDestination(for: PHAssetCollection.self) { collection in
                SharedAlbumMainView(assetCollection: collection)
            }
        }
    }

    private func albumCard(_ album: (collection: PHAssetCollection, title: String, count: Int, thumbnail: UIImage?)) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let thumbnail = album.thumbnail {
                Image(uiImage: thumbnail)
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

            Text(album.title)
                .font(.subheadline.weight(.medium))
                .textPrimary()
                .lineLimit(1)

            HStack(spacing: 4) {
                Text("\(album.count)")
                    .font(.caption)
                    .foregroundStyle(Color.theme.textSecondary)

                if let clique = cloudCliquesStore.cliqueForAlbum(title: album.title) {
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(Color.theme.textSecondary)
                    Image(systemName: "person.2.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.theme.buttonCTA)
                    Text("\(clique.cliqueName) (\(clique.memberCount))")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.theme.buttonCTA)
                }
            }
            .lineLimit(1)
        }
    }

    private var albumPlaceholder: some View {
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
                .frame(width: 30, height: 12)
                .roundCorners(4)
        }
    }

    // MARK: - Cloud Cliques Section

    private var createCliqueMessageBody: String {
        var body = "Join my Clique!\nhttps://apps.apple.com/us/app/clique-group-social/id6742713460"
        if let cliqueId = createdCliqueId {
            body += "\nclique://clique/\(cliqueId)"
        }
        return body
    }

    @ViewBuilder private var cloudCliquesSection: some View {
        if cloudCliquesStore.isLoaded && cloudCliquesStore.cliques.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("Your Cliques")
                    .font(.subheadline.weight(.semibold))
                    .textPrimary()
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                Button {
                    createCliqueFromList()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.2.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.theme.buttonCTA)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Create a Clique")
                                .font(.subheadline.weight(.semibold))
                                .textPrimary()
                            Text("Group your shared albums together")
                                .font(.caption)
                                .foregroundStyle(Color.theme.textSecondary)
                        }
                        Spacer()
                        if isCreatingClique {
                            ProgressView()
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.theme.textSecondary)
                        }
                    }
                    .padding(14)
                    .background(Color.theme.surfacesElevatedPrimary)
                    .roundCorners(12)
                }
                .buttonStyle(.plain)
                .disabled(isCreatingClique)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        } else if !cloudCliquesStore.cliques.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("Your Cliques")
                    .font(.subheadline.weight(.semibold))
                    .textPrimary()
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(cloudCliquesStore.cliques, id: \.cliqueId) { clique in
                            HStack(spacing: 6) {
                                Image(systemName: "person.2.fill")
                                    .font(.caption2)
                                Text(clique.cliqueName)
                                    .font(.caption.weight(.medium))
                                Text("\(clique.albumTitles.count)")
                                    .font(.caption2)
                                    .foregroundStyle(Color.theme.textSecondary)
                            }
                            .foregroundStyle(Color.theme.buttonCTA)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.theme.buttonCTA.opacity(0.1))
                            .roundCorners(20)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.top, 8)
            }
        }
    }

    private func createCliqueFromList() {
        guard !isCreatingClique else { return }
        isCreatingClique = true
        Task {
            do {
                let firstName = userStore.currentUser?.firstname ?? "My"
                let cliqueId = try await CloudCliqueService.createCloudClique(name: "\(firstName)'s Clique")
                await cloudCliquesStore.refresh()
                createdCliqueId = cliqueId
                isCreatingClique = false
                showMessageCompose = true
            } catch {
                print("[SharedAlbumsListView] Failed to create clique: \(error)")
                isCreatingClique = false
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.largeTitle)
                .foregroundStyle(Color.theme.textSecondary)

            Text("No shared albums found.")
                .font(.subheadline)
                .foregroundStyle(Color.theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
}
