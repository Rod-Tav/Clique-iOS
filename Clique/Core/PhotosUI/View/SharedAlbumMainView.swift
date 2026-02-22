//
//  SharedAlbumMainView.swift
//  Clique
//
//  Main view for a shared album with header + photo grid + hero detail overlay.
//  Mirrors CollectionMainView layout pattern but backed by PHAsset data.
//

import SwiftUI
import Photos
import MessageUI

@available(iOS 26, *)
struct SharedAlbumMainView: View {
    let assetCollection: PHAssetCollection

    @Environment(\.dismiss) var dismiss
    @Environment(SharedAlbumsData.self) var sharedData
    @Environment(SharedAlbumActivityStore.self) var activityStore
    @Environment(CloudCliquesStore.self) var cloudCliquesStore
    @Environment(UserStore.self) var userStore

    @State var assets: [PHAsset] = []
    @State var isLoading: Bool = true
    @State var previousPrefetchRange: Range<Int> = 0..<0
    @State var coordinator = SharedAlbumCoordinator()
    @State var heroCoordinator = HeroCoordinator()
    @State var showCliquePickerSheet: Bool = false
    @State var showMessageCompose: Bool = false
    @State var isCreatingClique: Bool = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    private var albumTitle: String {
        assetCollection.localizedTitle ?? "Album"
    }

    private var linkedClique: CloudCliqueInfo? {
        cloudCliquesStore.cliqueForAlbum(title: albumTitle)
    }

    private var messageBody: String {
        var body = "Add your pics to \(albumTitle) on Clique!\nhttps://apps.apple.com/us/app/clique-group-social/id6742713460"
        if let cliqueId = linkedClique?.cliqueId {
            body += "\nclique://clique/\(cliqueId)"
        }
        return body
    }

    private var coverThumbnail: UIImage? {
        guard let firstAsset = assets.first else { return nil }
        return sharedData.thumbnailCache[firstAsset]
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                albumHeader
                createCliqueCTA
                gridContent
            }
        }
        .sheet(isPresented: $showMessageCompose) {
            if MFMessageComposeViewController.canSendText() {
                MessageComposer(recipients: [], body: messageBody)
            }
        }
        .sheet(isPresented: $showCliquePickerSheet) {
            CliquePickerSheet(albumTitle: albumTitle, onLinked: {
                Task { await cloudCliquesStore.refresh() }
            })
        }
        .disabled(!coordinator.canInteract)
        .ignoresSafeArea(edges: .top)
        .navigationBarBackButtonHidden()
        .onScrollGeometryChange(for: PhotosScrollInfo.self) { geo in
            PhotosScrollInfo(
                offsetY: geo.contentOffset.y + geo.contentInsets.top,
                containerHeight: geo.containerSize.height
            )
        } action: { (_: PhotosScrollInfo, info: PhotosScrollInfo) in
            updatePrefetchRange(scrollOffset: info.offsetY, containerHeight: info.containerHeight)
        }
        .heroOverlay {
            SharedAlbumPhotoDetailView(assets: assets)
                .environment(coordinator)
        }
        .environment(heroCoordinator)
        .onDisappear {
            stopPrefetching()
        }
        .task {
            fetchAlbumPhotos()
        }
    }

    // MARK: - Album Header

    private var albumHeader: some View {
        ZStack(alignment: .bottomLeading) {
            // Cover image
            if let cover = coverThumbnail {
                Image(uiImage: cover)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 300)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.15))
                    .frame(height: 300)
            }

            // Gradient overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.6)],
                startPoint: .center,
                endPoint: .bottom
            )

            // Header info
            VStack(alignment: .leading, spacing: 4) {
                backButton

                Spacer()

                Text(albumTitle)
                    .font(.title.bold())
                    .foregroundStyle(.white)

                Text("\(assets.count) photos")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))

                if let clique = cloudCliquesStore.cliqueForAlbum(title: albumTitle) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.2.fill")
                            .font(.caption)
                        Text(clique.cliqueName)
                            .font(.subheadline.weight(.medium))
                        Text("\(clique.memberCount) \(clique.memberCount == 1 ? "member" : "members")")
                            .font(.caption)
                            .opacity(0.8)
                    }
                    .foregroundStyle(.white)
                } else if !cloudCliquesStore.unlinkedCliques().isEmpty {
                    Button {
                        showCliquePickerSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                                .font(.caption)
                            Text("Link to Clique")
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial.opacity(0.4))
                        .roundCorners(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .padding(.top, 60)
        }
        .frame(height: 300)
    }

    private var backButton: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                IconImage(name: "arrow-left", color: .theme.white, size: 24)
                    .padding(8)
                    .background(.ultraThinMaterial.opacity(0.6))
                    .roundCorners(20)
            }
            .buttonStyle(.noHighlight)

            Spacer()
        }
    }

    // MARK: - Create Clique CTA

    private var createCliqueCTA: some View {
        CliqueButton(
            type: .primary,
            leadingIcon: linkedClique != nil ? "send" : "plus",
            text: linkedClique != nil ? "Invite Friends" : "Create Clique",
            fullWidth: true,
            isLoading: isCreatingClique
        ) {
            if linkedClique != nil {
                showMessageCompose = true
            } else {
                createCliqueAndInvite()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func createCliqueAndInvite() {
        guard !isCreatingClique else { return }
        isCreatingClique = true

        Task {
            do {
                let firstName = userStore.currentUser?.firstname ?? "My"
                let cliqueName = "\(firstName)'s Clique"
                _ = try await CloudCliqueService.createCloudClique(name: cliqueName, albumTitle: albumTitle)
                await cloudCliquesStore.refresh()
                isCreatingClique = false
                showMessageCompose = true
            } catch {
                print("[SharedAlbumMainView] Failed to create clique: \(error)")
                isCreatingClique = false
            }
        }
    }

    // MARK: - Grid Content

    @ViewBuilder
    private var gridContent: some View {
        if isLoading {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(0..<18, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 120)
                        .shimmer()
                }
            }
        } else if assets.isEmpty {
            emptyState
        } else {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(assets, id: \.localIdentifier) { asset in
                    TappablePhotosGridCell(
                        thumbnail: sharedData.thumbnailCache[asset],
                        identifier: asset.localIdentifier
                    ) {
                        coordinator.selectedImageId = asset.localIdentifier
                    }
                    .id(asset.localIdentifier)
                    .task {
                        loadThumbnail(for: asset)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle")
                .font(.largeTitle)
                .foregroundStyle(Color.theme.textSecondary)

            Text("No photos in this album.")
                .font(.subheadline)
                .foregroundStyle(Color.theme.textSecondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Prefetching

    private func updatePrefetchRange(scrollOffset: CGFloat, containerHeight: CGFloat) {
        let rowHeight: CGFloat = 122
        let cols = 3
        let margin = 60
        let topRow = max(0, Int(scrollOffset / rowHeight))
        let visibleRows = Int(ceil(containerHeight / rowHeight)) + 1
        let firstVisible = topRow * cols
        let lastVisible = (topRow + visibleRows) * cols

        let totalCount = assets.count
        guard totalCount > 0, firstVisible < lastVisible else { return }

        let newStart = max(0, firstVisible - margin)
        let newEnd = min(totalCount, lastVisible + margin)
        let newRange = newStart..<newEnd

        guard newRange != previousPrefetchRange else { return }

        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        let oldIndices = Set(previousPrefetchRange)
        let newIndices = Set(newRange)

        let toStop = oldIndices.subtracting(newIndices)
        let toStart = newIndices.subtracting(oldIndices)

        if !toStop.isEmpty {
            let stopAssets = toStop.compactMap { $0 < totalCount ? assets[$0] : nil }
            sharedData.imageManager.stopCachingImages(for: stopAssets, targetSize: sharedData.thumbnailSize, contentMode: .aspectFill, options: options)
        }

        if !toStart.isEmpty {
            let startAssets = toStart.compactMap { $0 < totalCount ? assets[$0] : nil }
            sharedData.imageManager.startCachingImages(for: startAssets, targetSize: sharedData.thumbnailSize, contentMode: .aspectFill, options: options)
        }

        previousPrefetchRange = newRange
    }

    private func stopPrefetching() {
        if !previousPrefetchRange.isEmpty {
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true
            let stopAssets: [PHAsset] = previousPrefetchRange.compactMap { $0 < assets.count ? assets[$0] : nil }
            sharedData.imageManager.stopCachingImages(for: stopAssets, targetSize: sharedData.thumbnailSize, contentMode: .aspectFill, options: options)
            previousPrefetchRange = 0..<0
        }
    }

    // MARK: - Data Loading

    private func fetchAlbumPhotos() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let result = PHAsset.fetchAssets(in: assetCollection, options: fetchOptions)
        var fetched: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            fetched.append(asset)
        }

        assets = fetched
        isLoading = false

        activityStore.markAlbumSeen(
            albumLocalIdentifier: assetCollection.localIdentifier,
            title: albumTitle,
            currentCount: fetched.count
        )
    }

    private func loadThumbnail(for asset: PHAsset) {
        guard sharedData.thumbnailCache[asset] == nil else { return }

        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        options.resizeMode = .fast

        sharedData.imageManager.requestImage(
            for: asset,
            targetSize: sharedData.thumbnailSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            if let image {
                DispatchQueue.main.async {
                    self.sharedData.thumbnailCache[asset] = image
                }
            }
        }
    }
}
