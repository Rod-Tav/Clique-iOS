//
//  FlicksFeedView.swift
//  Clique
//
//  Created by Rod Tavangar on 6/19/25.
//

import SwiftUI
import AdvancedList
import Toasts

struct FlicksFeedView: View {
    @AppStorage("hasSwipedUpToOpenComments") private var hasSwipedUpToOpenComments: Bool = false
    
    @Environment(\.presentToast) private var presentToast
    
    @Environment(AppCoordinator.self) private var appCoordinator
    @Environment(TabViewCoordinator.self) private var tabViewCoordinator
    
    @Environment(CliqueStore.self) private var cliqueStore
    @Environment(UserStore.self) private var userStore
    @Environment(CollectionStore.self) private var collectionStore
    @Environment(CollectionImageStore.self) private var collectionImageStore
    
    @State private var viewModel: InfiniteFlickFeedPaginationViewModel
    @State private var listState: ListState = .loading
    @State private var paginationState: AdvancedListPaginationState = .idle
    @State private var isScrollAtBottom: Bool = false
    
    @State private var currentFlickId: String? = nil
    @State private var currentRelevantUser: User? = nil
    @State private var currentCollection: ClCollection? = nil
    @State private var currentCliqueMembers: [User]? = nil
    
    @State private var likeAnimation: Bool = false // TODO: DRY
    
    @State private var showCommentSheet: Bool = false
    @State private var showAddFriendsSheet: Bool = false
    @State private var showLikedMembers: Bool = false
    @State private var showDeleteFlickAlert: Bool = false
    @State private var showReportCover: Bool = false
    @State private var showCliqueMembers: Bool = false
    
    @State var loadedImage: UIImage?
    
    // Grid view state
    @State private var showGrid: Bool = true  // Default to grid view
    @AppStorage("flicksGridColumns") private var gridColumns: Int = 3
    @State private var gridScrollPosition: String? = nil
    @State private var gridReaderProxy: ScrollViewProxy? = nil

    
    private var currentImage: CollectionImage? {
        if let currentFlickId {
            return collectionImageStore.images[currentFlickId]
        } else {
            return nil
        }
    }
    
    init(_ collectionStore: CollectionStore, _ collectionImageStore: CollectionImageStore, _ cliqueStore: CliqueStore, _ userStore: UserStore) {
        self.viewModel = .init(collectionStore, collectionImageStore, userStore, cliqueStore)
    }
    
    var body: some View {
        Group {
            if showGrid {
                gridView
            } else {
                existingCarouselView
            }
        }
    }
    
    @ViewBuilder private var existingCarouselView: some View {
        @Bindable var bindableTVC = tabViewCoordinator
        
        TabNavigationStack(path: $bindableTVC.flicksNavigationPath) {
            VStack(spacing: 0) {
                if !viewModel.items.isEmpty {
                    topBar
                    
                    if currentFlickId == viewModel.items.first?.id {
                        Text("Swipe left to see more flicks")
                            .font(.callout)
                            .foregroundStyle(Color.theme.shadesWhite95)
                            .padding(.top, 8)
                    }
                    
                    Spacer()
                }
                
                AdvancedList(viewModel.items, listView: { flicks in
                    FlickList(flicks)
                }, content: { item in
                    FlickImage(item.flick)
                        .ignoresSafeArea(.keyboard)
                        .onChange(of: currentFlickId, initial: true) {
                            guard currentFlickId == item.flick.id else { return }
                            currentRelevantUser = item.flick.owner
                            currentCollection = item.collection
                            currentCliqueMembers = item.cliqueMembers
                        }
                    //                        FlickFeedCell(flick: item.flick, collection: item.collection, relevantUser: owner, cliqueMembers: item.cliqueMembers)
                    // overlay the next image to preload high quality image
                        .overlay {
                            if let idx = viewModel.items.firstIndex(where: { $0.id == item.id }),
                               idx + 1 < viewModel.items.count {
                                let nextItem = viewModel.items[idx + 1]
                                if let nextImage = collectionImageStore.images[nextItem.id] {
                                    CollectionDetailImageAsyncView(urls: nextImage.imageUrl, quality: .high)
                                        .opacity(0)
                                }
                            }
                        }
                        .task {
                            try? await fetchCliqueRelationshipOrReturn(cid: item.collection.cliqueId, cliqueStore)
                            guard let url = item.flick.imageUrl?.highQualityUrl, isInClique(cid: item.collection.cliqueId, cliqueStore) else { return }
                            
                            loadedImage = await fetchImageWithKingfisher(from: url)
                        }
                }, listState: listState, emptyStateView: {
                    EmptyStateView()
                }, errorStateView: { _ in
                    ErrorStateView()
                }, loadingStateView: {
                    LoadingStateView()
                })
                .pagination(.init(type: .thresholdItem(offset: 1), shouldLoadNextPage: { Task { await updateFlicks(.loadNextPage) } }) { })
                .onAppear {
                    Task {
                        guard listState == .loading else { return }
                        await updateFlicks(.loadFirstPage)
                        if let first = viewModel.items.first {
                            currentFlickId = first.id
                        }
                    }
                }
                
                if !viewModel.items.isEmpty {
                    Spacer()
                    
                    BelowImage()
                }
            }
            .if(!viewModel.items.isEmpty) { view in
                view
                    .bottomTabBarPadding()
            }
            .background {
                if let currentImage {
                    CollectionDetailBackgroundAsyncImage(urls: currentImage.imageUrl, quality: .low)
                        .blur(radius: 12.5, opaque: true)
                        .overlay(Color.theme.surfacesImageBgDarkOverlay)
                        .overlay(.black.opacity(0.2))
                }
            }
            .sheet(isPresented: $showAddFriendsSheet) {
                AddContactsView()
                    .bottomSheetModifiers()
            }
            .commentSheet(imageId: currentFlickId, fromCollectionDetail: false, showCommentSheet: $showCommentSheet)
        }
        .onReceive(of: .refreshFlicksFeed) { _ in
            refreshFeed()
        }
    }
    
    @ViewBuilder private var gridView: some View {
        @Bindable var bindableTVC = tabViewCoordinator
        
        TabNavigationStack(path: $bindableTVC.flicksNavigationPath) {
            VStack(spacing: 0) {
                // Grid header with toggle next to title
                gridTopBar
                
                // Use AdvancedList for proper pagination like CollectionMainView
                ScrollViewReader { reader in
                    AdvancedList(viewModel.items, listView: { items in
                        GridLayout(items)
                    }, content: { item in
                        if let imageUrl = collectionImageStore.images[item.flick.id]?.imageUrl {
                            GridCell(item, urls: imageUrl)
                        }
                    }, listState: listState, emptyStateView: {
                        EmptyStateView()
                    }, errorStateView: { _ in
                        ErrorStateView()
                    }, loadingStateView: {
                        LoadingStateView()
                    })
                    .pagination(.init(type: .lastItem, shouldLoadNextPage: {
                        Task { await updateFlicks(.loadNextPage) }
                    }) { })
                    .onAppear {
                        gridReaderProxy = reader
                        // Scroll to position if we have one
                        if let gridScrollPosition = gridScrollPosition {
                            reader.scrollTo(gridScrollPosition, anchor: .center)
                        }
                    }
                }
                .bottomTabBarPadding()
            }
            .primaryBackground()
        }
        .task {
            guard listState == .loading else { return }
            await updateFlicks(.loadFirstPage)
            if let first = viewModel.items.first {
                currentFlickId = first.id
                gridScrollPosition = first.id
            }
        }
        .onChange(of: showGrid) { oldValue, newValue in
            if newValue == true {
                // Switching TO grid: sync grid position from carousel and scroll to it
                gridScrollPosition = currentFlickId
                if let scrollId = currentFlickId, let proxy = gridReaderProxy {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(scrollId, anchor: .center)
                        }
                    }
                }
            } else {
                // Switching TO carousel: sync carousel position from grid  
                currentFlickId = gridScrollPosition
            }
        }
        .onReceive(of: .refreshFlicksFeed) { _ in
            refreshFeed()
        }
    }
    
    // MARK: - Top Bar
    private var gridTopBar: some View {
        TopAppBar(
            type: .medium,
            leadingIcon: { },
            header: { HeaderTextStar("Flicks") },
            trailingIcon: {
                Menu {
                    ForEach([2, 3, 4], id: \.self) { count in
                        Button {
                            gridColumns = count
                        } label: {
                            HStack {
                                Text("\(count) columns")
                                if gridColumns == count {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.grid.3x3")
                            .font(.callout)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .textSecondary()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.theme.textSecondary.opacity(0.1))
                    .roundCorners(6)
                }
            }
        )
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
    
    private func GridLayout(_ items: AdvancedList.Rows) -> some View {
        ScrollView {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: gridColumns),
                spacing: 2,
                content: items
            )
            .scrollTargetLayout()
        }
    }
    
    private func GridCell(_ item: InfiniteFeedItem, urls: PhotoUrls) -> some View {
        GridCollectionPreviewImage(urls: urls)  // Use new lightweight grid component
            .overlayCollectionPreviewStats(
                likes: item.flick.numLikes,
                comments: item.flick.numComments,
                hasLiked: item.flick.hasLiked
            )
            .id(item.flick.id)
            .contentShape(.rect)
            .onTapGesture {
                gridScrollPosition = item.flick.id  // Update grid position
                currentFlickId = item.flick.id      // Update carousel position
                showGrid = false                    // Switch to carousel
            }
    }
    
    private func refreshFeed() {
        Task {
            // Clear cache for flicks feed
            await CacheControl.shared.refreshFlicksFeed()
            
            await updateFlicks(.refresh)
            currentFlickId = viewModel.items.first?.id
            tabViewCoordinator.isFlicksFeedRefreshing = false
        }
    }
    
    private var topBar: some View {
        HStack(spacing: 0) {
            if let currentRelevantUser {
                NavigationLink(value: currentRelevantUser) {
                    HStack(spacing: 12) {
                        UserPfpAsyncView(pfp: currentRelevantUser.profilePic, size: 36, quality: .low)
                        
                        Group {
                            if currentRelevantUser.id == userStore.currentUserId {
                                Text("From **Your** Clique")
                            } else {
                                Text("From **\(currentRelevantUser.firstname)'s** Clique")
                            }
                        }
                        .font(.footnote)
                        .foregroundStyle(Color.theme.shadesWhite95)
                        
                        Spacer()
                        
                        Menu {
                            if let cid = currentCollection?.cliqueId, isInClique(cid: cid, cliqueStore), let loadedImage {
                                ShareLink(
                                    item: Image(uiImage: loadedImage),
                                    preview: SharePreview("", image: Image(uiImage: loadedImage))
                                ) {
                                    Text("Share Image")
                                    
                                    Image("share")
                                        .color(.theme.iconPrimary)
                                }
                                
                                Button {
                                    Task {
                                        guard let imageUrl = currentImage?.imageUrl, let url = imageUrl.highQualityUrl, let date = currentImage?.date, let loadedImage = await fetchImageWithKingfisher(from: url) else { return }
                                        
                                        let imageSaver = ImageSaver()
                                        imageSaver.writeToPhotoAlbum(image: loadedImage, date: date) { success in
                                            presentToast(success ? Toasts.savedImage : Toasts.somethingWentWrong)
                                        }
                                    }
                                } label: {
                                    Text("Save Image")
                                    Image("download")
                                        .color(.theme.iconPrimary)
                                }
                                
                                DeleteButton {
                                    showDeleteFlickAlert = true
                                }
                            }
                            
                            ReportButton {
                                showReportCover = true
                            }
                        } label: {
                            EllipsisImage(color: .theme.white, size: 24)
                        }
                        .fullScreenCover(isPresented: $showReportCover) {
                            if let currentFlickId {
                                ReportView(showReport: $showReportCover, objectId: currentFlickId, reportType: .image)
                            }
                        }
                        .alert(isPresented: $showDeleteFlickAlert) {
                            Alert(
                                title: Text("Are you sure you want to delete this flick?"),
                                message: Text("This action cannot be undone."),
                                primaryButton: .destructive(Text("Delete")) {
                                    guard let currentFlickId, let currentCollection else { return }
                                    
                                    Task {
                                        do {
                                            try await CollectionService.deleteCollectionItem(.init(path: .init(collectionItemId: currentFlickId)))
                                            
                                            viewModel.items.removeAll(where: { $0.id == currentFlickId })
                                            collectionStore.collections[currentCollection.id]?.images.removeAll(where: { $0.id == currentFlickId })
                                            collectionStore.collections[currentCollection.id]?.numFlicks -= 1
                                            collectionImageStore.images.removeValue(forKey: currentFlickId)
                                            
                                            trigger(.refreshCollectionCells, object: [currentCollection.id])
                                        } catch {
                                            presentToast(Toasts.somethingWentWrong)
                                        }
                                    }
                                },
                                secondaryButton: .cancel()
                            )
                        }
                    }
                }
                .noHighlight()
            }
            
            Spacer()
            
            Button {
                showGrid = true
                // currentFlickId is already synced automatically
            } label: {
                Image(systemName: "square.grid.3x3")
                    .foregroundColor(.white)
                    .font(.title3)
            }
        }
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder private func BelowImage() -> some View {
        VStack(spacing: 24) {
            HStack {
                if let currentCollection, let currentCliqueMembers, let currentImage {
                    NavigationLink(value: currentCollection) {
                        HStack(spacing: 4) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(currentCollection.name)
                                        .font(.callout.bold())
                                        .foregroundStyle(Color.theme.shadesWhite95)
                                    
                                    if currentCollection.visibility == .priv {
                                        IconImage("lock", color: .theme.shadesWhite95, size: 16)
                                            .padding(.leading, 2)
                                    }
                                    
                                    IconImage("chevron-right", color: .theme.shadesWhite95, size: 16)
                                }
                                
                                Text("\(formatDateMMMMdd(currentImage.date)) • \(formatDateHHmm(currentImage.date))")
                                    .font(.caption2)
                                    .foregroundStyle(Color.theme.shadesWhite95)
                            }
                            .maxWidth(.leading)
                            
                        }
                        .contentShape(.rect)
                    }.noHighlight()
                    
                    CliqueCircularMembersView(
                        members: currentCliqueMembers,
                        memberLimit: 5,
                        type: .medium,
                        forceDark: true
                    )
                    .onHighPriorityTap {
                        showCliqueMembers.toggle()
                    }
                    .sheet(isPresented: $showCliqueMembers) { // TODO: DRY
                        CliqueMembersListSheetView(cid: currentCollection.cliqueId, fromFeed: true, userStore, cliqueStore)
                            .presentationDetents([.fraction(0.35), .fraction(0.999)])
                            .bottomSheetModifiers()
                    }
                    //                    FlickCliqueMembersView(cid: collection.cliqueId)
                }
            }
            
            HStack(spacing: 16) {
                Button {
                    tabViewCoordinator.focusCommentKeyboard = true
                    showCommentSheet = true
                } label: {
                    ZStack(alignment: .leading) {
                        if let currentUser = userStore.currentUser {
                            UserPfpAsyncView(pfp: currentUser.profilePic, size: 32, quality: .low)
                                .zIndex(1)
                        }
                        
                        HStack(spacing: 8) {
                            Text("Add a comment...")
                                .font(.footnote)
                                .foregroundColor(Color.theme.white)
                                .maxWidth(.leading)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.15))
                        .roundCorners(16)
                        .maxWidth()
                        .offset(x: 32-8)
                        .padding(.trailing, 32-8)
                    }
                    .maxWidth(.leading)
                }.buttonStyle(.noHighlight)
                
                if let currentImage {
                    HStack(spacing: 6) { // TODO: DRY
                        Button {
                            haptics(.medium)
                            handleLikeTapped()
                        } label: {
                            IconImage("heart-filled", color: currentImage.hasLiked ? .theme.red : .theme.white, size: 28)
                        }
                        
                        Button {
                            showLikedMembers = true
                        } label: {
                            Text(formatNumber(currentImage.numLikes))
                                .font(.footnote.bold())
                                .foregroundStyle(Color.theme.white)
                        }
                    }
                    .sheet(isPresented: $showLikedMembers) {
                        LikedUsersListView(imageId: currentImage.id, fromCollectionDetail: true, userStore)
                            .presentationDetents([.fraction(0.35), .fraction(0.999)])
                            .bottomSheetModifiers()
                    }
                    
                    Button {
                        showCommentSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            IconImage("comment-filled", color: .theme.white, size: 28)
                            
                            Text(formatNumber(currentImage.numComments))
                                .font(.footnote)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.theme.white)
                        }
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder private func FlickList(_ flicks: AdvancedList.Rows) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 12, content: flicks)
                .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $currentFlickId)
    }
    
    private func handleLikeTapped() {
        if let currentFlickId, let selectedImage = collectionImageStore.images[currentFlickId] {
            do {
                try handleCollectionImageLikeTapped(image: selectedImage, collectionImageStore)
            } catch {
                presentToast(Toasts.somethingWentWrong)
            }
        }
    }
    
    // MARK: Flick Image
    @ViewBuilder private func FlickImage(_ image: CollectionImage) -> some View {
        CollectionDetailImageAsyncView(urls: image.imageUrl, quality: .high)
        // TODO: DRY
            .contentShape(.rect)
            .id(image.id)
            .pinchZoom()
            .scrollTransition { content, phase in
                content
                    .opacity(phase.isIdentity ? 1 : 0.7)
                    .scaleEffect(phase.isIdentity ? 1 : 0.85)
            }
            .doubleTapToLike(hasLiked: image.hasLiked, likeAnimation: $likeAnimation) {
                handleLikeTapped()
            }
            .overlay {
                IconImage("heart-filled", color: .theme.red, size: 70)
                    .likeAnimation($likeAnimation)
            }
            .swipeUpToOpenCommentsTutorial()
            .simultaneousGesture(swipeUpToOpenComments)
    }
    
    private var swipeUpToOpenComments: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                // Check if the swipe was mostly vertical and upwards
                if value.translation.height < -20 && abs(value.translation.width) < 20 {
                    haptics(.light)
                    showCommentSheet = true
                    hasSwipedUpToOpenComments = true
                }
            }
    }
}

// MARK: - Pagination state views
extension FlicksFeedView {
    @ViewBuilder private func EmptyStateView() -> some View {
        VStack(spacing: 16) { // TODO: DRY
            VStack(spacing: 8) {
                IconImage("search", color: .primaryIcon, size: 32)
                
                Text("Clique is way more fun with friends. Let’s add some?")
                    .textPrimary()
                    .multilineTextAlignment(.center)
                    .font(.footnote)
            }
            
            HStack(spacing: 8) {
                CliqueButton(
                    type: .tertiary,
                    leadingIcon: "plus",
                    text: "Add Friends"
                ) {
                    showAddFriendsSheet = true
                }
                
                CliqueButton(
                    type: .tertiary,
                    leadingIcon: "3-user",
                    text: "Create Clique"
                ) {
                    tabViewCoordinator.showCliqueCreator = true
                }
            }
            
            CliqueButton(
                type: .tertiary,
                leadingIcon: "refresh",
                text: "Refresh Feed"
            ) {
                refreshFeed()
            }
        }
        .infiniteFrame()
    }
    
    @ViewBuilder private func ErrorStateView() -> some View {
        SomethingWentWrong {
            listState = .loading
            await updateFlicks(.refresh)
        }
        .padding(.horizontal, 16)
        .maxHeight()
    }
    
    @ViewBuilder private func LoadingStateView() -> some View {
        CliqueProgressView()
            .infiniteFrame()
            .primaryBackground()
    }
    
    private func updateFlicks(_ operation: PaginationOperationType) async {
        if operation == .refresh {
            viewModel.first = true
            viewModel.seed = Int(Int32.random(in: Int32.min..<Int32.max))
        }
        
        await PaginationHelper.updateItems(
            operation,
            viewModel: viewModel,
            listState: $listState,
            paginationState: $paginationState,
            isScrollAtBottom: $isScrollAtBottom
        )
    }
}
