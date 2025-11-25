//
//  CollectionMainView.swift
//  Clique
//
//  Created by Rod Tavangar on 12/15/24.
//

import SwiftUI
import Toasts
import AdvancedList

struct CollectionMainView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.safeAreaInsets) private var safeAreaInsets
    @Environment(\.presentToast) private var presentToast
    
    @Environment(UserStore.self) private var userStore
    @Environment(CliqueStore.self) private var cliqueStore
    @Environment(CollectionStore.self) private var collectionStore
    @Environment(CollectionImageStore.self) private var collectionImageStore
    
    @Environment(AppCoordinator.self) private var appCoordinator
    @Environment(TabViewCoordinator.self) private var tabCoordinator
    
    @State private var imagesPgVM: CollectionImagesPaginationViewModel
    
    @State private var viewModel = CollectionViewModel()
    @State private var cliqueMembersVM: CliqueProfileViewModel
    @State private var clCoordinator: CollectionCoordinator
    @State private var heroCoordinator = HeroCoordinator()
    @State private var tabSwitcherCoordinator = ProfileTabSwitcherCoordinator()
    
    @State private var showCliqueMembersSheet: Bool = false
//    @State private var showAddPhotosSheet: Bool = false
    @State private var showReportCover: Bool = false
    @State private var showEditCollectionSheet: Bool = false
    @State private var showDeleteCollectionAlert: Bool = false
    @State private var showCollectionBanner: Bool = false

    // Context menu state (simplified)
    @State private var deleteAlertImage: CollectionImage?
    @State private var reportImage: CollectionImage?
    @State private var shareItem: ShareItem?
    @State private var showSharePreparation: Bool = false

    let collectionId: String
    let gallerySortTip = GallerySortTip()
    
    init(collectionId: String, cliqueId: String, _ collectionStore: CollectionStore, _ collectionImageStore: CollectionImageStore) {
        self.collectionId = collectionId
        self.clCoordinator = CollectionCoordinator(collectionId: collectionId)
        self.imagesPgVM = .init(collectionDataId: collectionId, sortOption: .timeAsc, collectionStore, collectionImageStore)
        self.cliqueMembersVM = .init(cid: cliqueId)
    }
    
    private var collection: ClCollection? {
        collectionStore.collections[collectionId]
    }
    
    private var clique: Clique? {
        guard let cid = collection?.cliqueId else { return nil }
        return cliqueStore.cliques[cid]
    }
    
    private var coverPhoto: PhotoUrls? {
        if let coverPhoto = collection?.coverPhoto {
            return coverPhoto
        } else if let mostLikedImage = collection?.mostLikedImage {
//          TODO: figure out  print(collection?.mostLikedImage)
            return collectionImageStore.images[mostLikedImage]?.imageUrl
        } else {
            return nil
        }
    }
    
    // MARK: - Body
    var body: some View {
        if collection != nil || collection?.images.first?.uiImage != nil {
            Group {
                if #available(iOS 18.0, *) {
                    // Simplified ScrollView for iOS 18+
                    ScrollView {
                        VStack(spacing: 0) {
                            CollectionExpandedHeader()
                            
                            CollectionContent()
                                .environment(clCoordinator)
                                .environment(imagesPgVM)
                        }
                    }
                    .ignoresSafeArea(edges: .top)
                    .primaryBackground()
                    .refreshable {
                        refreshAll()
                    }
                } else {
                    // iOS 17 fallback with ProfileTabSwitcher2
                    ProfileTabSwitcher2(
                        smallHeaderView: CollectionCollapsedHeader(),
                        largeHeaderView: CollectionExpandedHeader()
                    ) {
                        CollectionContentStruct() {
                            CollectionContent()
                        }
                        .environment(clCoordinator)
                        .environment(imagesPgVM)
                    }
                    .environment(tabSwitcherCoordinator)
                }
            }
            .heroOverlay {
                CollectionDetailView()
                    .environment(clCoordinator)
                    .environment(imagesPgVM)
            }
            .environment(tabSwitcherCoordinator)
            .environment(heroCoordinator)
            // TODO: tagged members
            .sheet(isPresented: $showCliqueMembersSheet) {
                if let clique {
                    CliqueMembersListSheetView(cid: clique.id, userStore, cliqueStore)
                        .presentationDetents([.fraction(0.999)])
                        .bottomSheetModifiers()
                }
            }
            .sheet(isPresented: $showEditCollectionSheet) {
                if let collection {
                    EditCollectionSheet(clique: clique, members: cliqueMembersVM.firstXMembers, collection: collection)
                        .bottomSheetModifiers()
                }
            }
            .onAppear { // TODO: DRY
                Task {
                    guard let clique, cliqueMembersVM.firstXMembers.count < min(clique.numMembers, 5) else { return }
                    
                    do {
                        try await cliqueMembersVM.fetchCliqueFirstXMembers(count: 5, total: clique.numMembers, userStore, cliqueStore)
                    } catch {
                        presentToast(Toasts.somethingWentWrong)
                    }
                }
            }
            //            .onChange(of: imagesPgVM.items) { _, newValue in
            //                CollectionImagePrefetcher.instance.prefetchHighQuality(collectionId: collectionId, images: newValue.compactMap({ collectionImageStore.images[$0.id] }))
            //            }
            .onDisappear {
                CollectionImagePrefetcher.instance.stopPrefetching(collectionId: collectionId)
            }
//            .onChange(of: appCoordinator.triggerAddPhotosCover) {
//                showAddPhotosSheet = true
//            }
//            .fullScreenCover(isPresented: $showAddPhotosSheet) {
//                AddPhotosCover(collectionId: collectionId)
//            }
            .fullScreenCover(isPresented: $showReportCover) {
                ReportView(showReport: $showReportCover, objectId: collectionId, reportType: .collection)
            }
            .collectionImageContextMenuHandlers(
                deleteAlertImage: $deleteAlertImage,
                reportImage: $reportImage,
                shareItem: $shareItem,
                showSharePreparation: $showSharePreparation,
                onDelete: { image in
                    await CollectionImageSaveHelpers.deleteCollectionItem(
                        imageId: image.id,
                        collectionId: collectionId,
                        collectionStore: collectionStore,
                        collectionImageStore: collectionImageStore,
                        presentToast: { toast in presentToast(toast) },
                        onSuccess: {
                            refreshAll()
                        }
                    )
                }
            )
            .fullScreenCover(isPresented: $showCollectionBanner) {
                ExpandedPfpView {
                    ExpandedBannerAsyncImage(banner: coverPhoto, type: .clique, quality: .high, showGradient: false)
                }
            }
            .onAppear {
                guard let collection else { return }
                Task {
                    do {
                        try await viewModel.fetchClique(cid: collection.cliqueId, cliqueStore)
                    } catch {
                        presentToast(Toasts.somethingWentWrong)
                    }
                }
            }
            .fetchCliqueRelationship(cid: collection?.cliqueId)
            .fetchMostLikedImage(collectionId: collectionId)
            .onChange(of: imagesPgVM.sortOption) {
                Task {
                    await updateImages(.refresh)
                }
            }
        }
    }
}

// MARK: - Headers
extension CollectionMainView {
    /// Collapsed header
    @ViewBuilder private func CollectionCollapsedHeader() -> some View {
        ZStack(alignment: .bottom) {
            if let coverPhoto {
                CollapsedBannerAsyncImage(banner: coverPhoto, quality: .high)
            } else {
                CollapsedBannerPlaceholder()
            }
            
            TopAppBar(
                type: .small,
                leadingIcon: {
                    BackButton(color: .theme.white, size: 24)
                },
                header: CollapsedHeaderInfo,
                trailingIcon: {
                    SortMenu()
                }
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }
    
    @ViewBuilder private func SortMenu() -> some View {
        Menu {
            Picker("Sort by", selection: $imagesPgVM.sortOption) {
                ForEach(SortOption.allCases) { option in
                    Label(option.title, systemImage: option.systemImage)
                }
            }
        } label: {
            IconImage(name: "sort", color: .theme.white, size: 24)
                .popoverTip(gallerySortTip)
                .onTapGesture {
                    gallerySortTip.invalidate(reason: .actionPerformed)
                }
        }
    }
    
    @ViewBuilder private func EllipsisMenu(clique: Clique?) -> some View {
        Menu {
            if #unavailable(iOS 18.0) {
                RefreshMenuButton {
                    refreshAll()
                }
            }

            ShareCollectionButton(
                collectionId: collectionId,
                collectionName: collection?.name,
                collectionDescription: collection?.description
            )

            ReportButton {
                showReportCover = true
            }

            if let collection, isInClique(cid: collection.cliqueId, cliqueStore) {
                DeleteButton {
                    showDeleteCollectionAlert = true
                }
            }
        } label: {
            EllipsisImage(color: .theme.white, size: 24)
        }
        .alert(isPresented: $showDeleteCollectionAlert) {
            Alert(
                title: Text("Are you sure you want to delete this collection?"),
                message: Text("This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    // TODO: DRY
                    Task {
                        do {
                            try await CollectionService.deleteCollection(.init(path: .init(collectionDataId: clCoordinator.collectionId)))
                            tabCoordinator.clearPath()
                        } catch {
                            presentToast(Toasts.somethingWentWrong)
                        }
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    private func refreshAll() {
        Task {
            // Clear cache for this collection
            await CacheControl.shared.refreshCollection(collectionId)
            
            var newCollection = try await CollectionService.getCollectionById(.init(path: .init(collectionDataId: collectionId), query: .init(page: 0, size: 1, sort: mapFromSortOption(imagesPgVM.sortOption))))
            
            if imagesPgVM.sortOption == .likesDesc {
                newCollection.mostLikedImage = newCollection.images.first?.id
            }
            
            collectionStore.updateCollection(newCollection, forceUpdateURL: true, collectionImageStore)
            
            await updateImages(.refresh)
        }
    }
    
    /// Expanded header
    @ViewBuilder private func CollectionExpandedHeader() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            /// banner and toolbar
            ZStack(alignment: .top) {
                if let coverPhoto {
                    ExpandedBannerAsyncImage(banner: coverPhoto, type: .collection, quality: .medium)
                        .onTapGesture {
                            showCollectionBanner = true
                        }
                } else {
                    ExpandedBannerPlaceholder()
                }
                
                TopAppBar(
                    type: .small,
                    leadingIcon: {
                        BackButton(color: .theme.white, size: 24)
                    },
                    header: {},
                    trailingIcon: {
                        HStack(spacing: 8) {
                            SortMenu()
                            
                            EllipsisMenu(clique: clique)
                        }
                    }
                )
                .padding(.horizontal, 16)
                .padding(.top, safeAreaInsets.top)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                CollectionInfo()
                
                if let collection, isInClique(cid: collection.cliqueId, cliqueStore) {
                    HStack(spacing: 8) {
                        // TODO: DRY
                        Menu {
                            Button {
                                tabCoordinator.startCreateFlow(for: collection)
                            } label: {
                                Text("Camera")
                                Image("camera")
                                    .color(.theme.iconPrimary)
                            }
                            
                            Button {
                                tabCoordinator.startCreateFlow(for: collection, shouldOpenLibrary: true)
//                                showAddPhotosSheet = true
                            } label: {
                                Text("Library")
                                Image("images-posts")
                                    .color(.theme.iconPrimary)
                            }
                        } label: {
                            CliqueButton(
                                type: .primary,
                                leadingIcon: "plus",
                                text: "Add Flicks",
                                fullWidth: true
                            )
                        }
                    }
                }
            }
            .padding([.horizontal, .bottom], 24)
            .padding(.top, -24)
        }
    }
    
    /// Collapsed header info
    @ViewBuilder private func CollapsedHeaderInfo() -> some View {
        if let collection {
            VStack(spacing: 2) {
                Text(collection.name)
                    .font(.callout.bold())

                Text("\(formatDateMMMMdd(collection.creation)) • \(formatNumber(collection.displayFlickCount(currentUserId: userStore.currentUserId))) Flicks")
                    .font(.caption)
            }
            .multilineTextAlignment(.center)
            .foregroundStyle(Color.theme.white)
        }
    }
}

// MARK: - Info
extension CollectionMainView {
    @ViewBuilder private func CollectionInfo() -> some View {
        if let collection {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        if let clique = cliqueStore.cliques[collection.cliqueId] {
                            NavigationLink(value: clique) {
                                CliquePfpAsyncView(pfp: clique.cliquePic, type: .collection, quality: .low)
                            }
                            .noHighlight()
                        }
                        
                        Spacer()
                        
                        if !cliqueMembersVM.firstXMembers.isEmpty {
                            Button {
                                showCliqueMembersSheet = true
                            } label: {
                                CliqueCircularMembersView(members: cliqueMembersVM.firstXMembers, type: .cliqueProfile)
                            }.buttonStyle(.noHighlight)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        if let clique {
                            NavigationLink(value: clique) {
                                HStack(spacing: 4) {
                                    IconImage(name: "3-user", color: .theme.iconSecondary, size: 14)
                                    
                                    Text(clique.name)
                                        .font(.caption.bold())
                                        .textSecondary()
                                }
                            }.noHighlight()
                        }
                        
                        HStack(spacing: 4) {
                            Text(collection.name)
                                .textPrimary()
                                .font(.title3.bold())
                                .kerning(0.072)
                            
                            if collection.visibility.isPrivate {
                                IconImage(name: "lock", color: .theme.iconPrimary, size: 16)
                            }
                            
                            if let cid = clique?.id, isInClique(cid: cid, cliqueStore) {
                                Spacer()
                                
                                SmallCTA(
                                    type: .secondary,
                                    leadingIcon: "pen",
                                    text: "Edit",
                                    action: {
                                        showEditCollectionSheet = true
                                    }
                                )
                            }
                        }
                        
                        HStack(spacing: 2) {
                            HStack(spacing: 4) {
                                IconImage(name: "calendar", color: Color.theme.iconSecondary, size: 16)

                                Text(formatDateMMMMddYYYY(collection.creation))
                                    .font(.caption)
                                    .textSecondary()
                            }

                            let displayCount = collection.displayFlickCount(currentUserId: userStore.currentUserId)
                            Text("• \(formatNumber(displayCount)) \(displayCount == 1 ? "Flick" : "Flicks")")
                                .font(.caption)
                                .textSecondary()
                        }
                    }
                }
                
                if !collection.description.isEmpty {
                    Text(collection.description)
                        .textPrimary()
                        .font(.caption)
                        .onAppear {
                            print(collection.description) // getting cut off when max
                        }
                }
            }
        }
    }
}

// MARK: - Grid
extension CollectionMainView {
    @ViewBuilder private func CollectionContent() -> some View {
        AdvancedList(imagesPgVM.items, listView: { images in
            ImagesList(images)
        }, content: { imageID in
            if let image = collectionImageStore.images[imageID] {
                ImageCell(image)
            }
        }, listState: clCoordinator.listState, emptyStateView: {
            EmptyStateView()
        }, errorStateView: { _ in
            ErrorStateView()
        }, loadingStateView: {
            LoadingStateView()
        })
        .pagination(.init(type: .lastItem, shouldLoadNextPage: { Task { await updateImages(.loadNextPage) } }) { })
        .disabled(!clCoordinator.canInteract)
        .bottomTabBarPadding()
        .padding(.bottom, 16)
        .frameTop()
        .task {
            guard clCoordinator.listState == .loading else { return }
            await updateImages(.loadFirstPage)
        }
        .onReceive(of: .refreshCollectionImages) { noti in
            guard noti.checkEquals(collectionId) else { return }
            
            Task {
                print("refreshing collection main view")
                refreshAll()
            }
        }
    }
    
    @ViewBuilder private func ImagesList(_ images: AdvancedList.Rows) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 2, content: images)
    }
    
    @ViewBuilder private func ImageCell(_ image: CollectionImage) -> some View {
        CollectionPreviewAsyncImage(urls: image.imageUrl, quality: .low, isLivePhoto: image.isLivePhoto, isVideo: image.isVideo, uploadStatus: image.uploadStatus, itemId: image.id, onRefresh: refreshAll)
            .overlayCollectionPreviewStats(
                likes: image.numLikes,
                comments: image.numComments,
                hasLiked: image.hasLiked,
                isLivePhoto: image.isLivePhoto,
                isVideo: image.isVideo,
                videoDuration: image.videoDuration,
                videoUrl: image.videoUrls?.videoUrl(for: .medium)
            )
            .id(image.id)
            .heroSource(urls: image.imageUrl) {
                tabCoordinator.showTabBar = false
                clCoordinator.selectedImageId = image.id
            }
            .contextMenu {
                CollectionImageMenuContent(
                    image: image,
                    collectionId: collectionId,
                    showDeleteAlert: Binding(
                        get: { deleteAlertImage?.id == image.id },
                        set: { if $0 { deleteAlertImage = image } else { deleteAlertImage = nil } }
                    ),
                    showReportCover: Binding(
                        get: { reportImage?.id == image.id },
                        set: { if $0 { reportImage = image } else { reportImage = nil } }
                    ),
                    shareItem: $shareItem,
                    showSharePreparation: $showSharePreparation
                )
            }
    }
}

// MARK: - Pagination state views
extension CollectionMainView {
    // this should never happen
    @ViewBuilder private func EmptyStateView() -> some View {
        NothingHereYetView()
        //            .padding(.horizontal, 16)
        //            .frame(maxHeight: .infinity)
    }
    
    @ViewBuilder private func ErrorStateView() -> some View {
        SomethingWentWrong {
            clCoordinator.listState = .loading
            await updateImages(.refresh)
        }
        .padding(.horizontal, 16)
        .frame(maxHeight: .infinity)
    }
    
    @ViewBuilder private func LoadingStateView() -> some View {
        CliqueProgressView()
            .infiniteFrame()
    }
    
    private func updateImages(_ operation: PaginationOperationType) async {
        await PaginationHelper.updateItems(
            operation,
            viewModel: imagesPgVM,
            listState: $clCoordinator.listState,
            paginationState: $clCoordinator.paginationState,
            isScrollAtBottom: $clCoordinator.isScrollAtBottom
        )
    }
}

#Preview {
    CollectionMainView(collectionId: ClCollection.MOCK_COLLECTIONS[0].id, cliqueId: ClCollection.MOCK_COLLECTIONS[0].cliqueId, CollectionStore(), CollectionImageStore())
        .environment(CollectionViewModel())
        .environment(TabViewCoordinator())
        .environment(ProfileTabSwitcherCoordinator())
}


struct CollectionContentStruct<Content: View>: View {
    @Environment(ProfileTabSwitcherCoordinator.self) private var profileTabSwitcherCoordinator
    @Environment(CollectionCoordinator.self) private var coordinator
    @Environment(CollectionImagesPaginationViewModel.self) private var imagesPgVM
    //    @Binding var smallHeader: Bool
    //    @Binding var smallHeaderNoAnimation: Bool
    let content: () -> Content
    
    @State private var scrollOffset: CGFloat = 0
    @State private var canGoUp: Bool = true
    //    @State private var scrollID: Int?
    
    var body: some View {
        ScrollViewReader { reader in
            ScrollView {
                ZStack {
                    Spacer().containerRelativeFrame([.horizontal, .vertical]) // center content (for pagination states). will need to frameTop for items
                    
                    content()
                        .scrollTargetLayout()
                    //                        .simultaneousGesture(dragGesture)
                }
                .offsetY { value in
                    guard profileTabSwitcherCoordinator.canGoUp[0] != (value == 0) else { return }
                    profileTabSwitcherCoordinator.canGoUp[0] = (value == 0)
                }
            }
            .disableBounce()
            //            .scrollPosition(id: $scrollID)
            //            .scrollIndicators(.hidden)
            .scrollDisabled(!profileTabSwitcherCoordinator.smallHeaderAnimationComplete)
            .onChange(of: coordinator.selectedImageId) { oldValue, newValue in
                guard oldValue != nil, let newValue else { return }
                scrollToSelectedImage(in: reader, to: newValue)
            }
        }
    }
    
    //    private var dragGesture: some Gesture {
    //        DragGesture()
    //            .onChanged { value in
    //                profileTabSwitcherCoordinator.isScrolling = true
    //
    //                if scrollOffset != 0 {
    //                    canGoUp = false
    //                }
    //
    //                let isVerticalDrag = value.translation.height > 10 && abs(value.translation.width) < 20
    //
    //                if isVerticalDrag, canGoUp, profileTabSwitcherCoordinator.smallHeader, scrollOffset == 0 {
    //                    withAnimation(.easeInOut(duration: 0.25), completionCriteria: .logicallyComplete) {
    //                        profileTabSwitcherCoordinator.smallHeader = false
    //                    } completion: {
    //                        profileTabSwitcherCoordinator.smallHeaderAnimationComplete = false
    //                    }
    //                }
    //            }
    //            .onEnded { _ in
    //                canGoUp = true
    //                profileTabSwitcherCoordinator.isScrolling = false
    //            }
    //    }
    
    private func scrollToSelectedImage(in reader: ScrollViewProxy, to imageId: String) {
        //        if let image = imagesPgVM.items.first(where: { $0.id == newValue?.id }), oldValue != nil {
        /// Scroll to this item, as this is not visible on the screen
        var anchor: UnitPoint
        // TODO: index was removed so find other way to do this
        //            if image.index < 3 {
        //                anchor = .top
        //            } else if image.index < 6 {
        //                anchor = .bottom
        //            } else {
        if !profileTabSwitcherCoordinator.smallHeader {
            profileTabSwitcherCoordinator.smallHeader = true
            profileTabSwitcherCoordinator.smallHeaderAnimationComplete = true
        }
        anchor = .center
        //            }
        reader.scrollTo(imageId, anchor: anchor)
        //        }
    }
}
