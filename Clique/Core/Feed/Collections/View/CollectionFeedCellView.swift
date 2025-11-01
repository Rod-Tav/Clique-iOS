//
//  CollectionCellView.swift
//  Clique
//
//  Created by Rod Tavangar on 12/11/24.
//

import SwiftUI
import Toasts
import AdvancedList

struct CollectionFeedCellView: View {
    @AppStorage("lastSeenAppVersion") private var lastSeenVersion: String?
    
    @Environment(\.presentToast) private var presentToast
    
    @Environment(UserStore.self) private var userStore
    @Environment(CliqueStore.self) private var cliqueStore
    @Environment(CollectionStore.self) private var collectionStore
    @Environment(CollectionImageStore.self) private var collectionImageStore
    @Environment(CommentStore.self) private var commentStore
    
    @Environment(AppCoordinator.self) private var appCoordinator
    @Environment(TabViewCoordinator.self) private var tabViewCoordinator
    
    @State private var clCoordinator: CollectionCoordinator
    @State private var heroCoordinator = HeroCoordinator()
    
    @State private var viewModel = CollectionViewModel()
    @State private var cliqueMembersVM: CliqueProfileViewModel
    
    @State private var imagesPgVM: CollectionImagesPaginationViewModel
    
    @State private var scrollPosition: String?
    
    @State private var showReportCover: Bool = false
    @State private var showCliqueMembers: Bool = false
    @State private var showDetailView: Bool = false
    
    @State private var refreshTask: Task<Void, Never>?
    
    let collectionId: String
    var author: User?
    var relevantUser: User?
    let cliqueNumMembers: Int
    let cid: String
    var cliquePfp: PhotoUrls?
    let feedGalleryTip = FeedGalleryTip()
    
    private var collection: ClCollection? {
        collectionStore.collections[collectionId]
    }
    
    init(collectionId: String, clique: Clique, relevantUser: User?, initialImageIds: [String], _ collectionStore: CollectionStore, _ collectionImageStore: CollectionImageStore) {
        self.collectionId = collectionId
        self.relevantUser = relevantUser
        self.imagesPgVM = .init(collectionDataId: collectionId, sortOption: .likesDesc, collectionStore, collectionImageStore)
//        self.imagesPgVM.items = initialImageIds
        self.cid = clique.id
        self.cliqueMembersVM = .init(cid: cid)
        self.cliqueNumMembers = clique.numMembers
        self.cliquePfp = clique.cliquePic
        self.clCoordinator = .init(collectionId: collectionId)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: collection?.images.count == 1 ? 8 : collection?.images.count == 2 ? 12 : 16) {
                CollectionCellBanner()
                    .padding(.horizontal, 16)
                
                SwipeableCardStack()
            }
            
            BottomInfo()
                .padding(.horizontal, 16)
        }
        .onReceive(of: .refreshCollectionImages) { noti in
            guard let idToRefresh = noti.object as? String, idToRefresh == collectionId else { return }
            
            Task {
                print("refreshing collection feed cell")
                await refreshAsync()
            }
        }
        .fullScreenCover(isPresented: $showDetailView) {
            CollectionDetailView(fromGallery: false)
                .environment(clCoordinator)
                .environment(heroCoordinator)
                .environment(imagesPgVM)
                .presentationBackground(.clear)
        }
        .onAppear {
            Task {
                guard clCoordinator.listState == .loading else {
                    if scrollPosition == nil {
                        scrollPosition = imagesPgVM.items.first?.id // set only if nil
                    }
                    return
                }
                await updateImages(.loadFirstPage)
                scrollPosition = imagesPgVM.items.first?.id
            }
        }
        .fetchClique(cid: collection?.cliqueId)
        .fetchCliqueRelationship(cid: collection?.cliqueId)
        .fetchMostLikedImage(collectionId: collectionId)
        .onAppear {
            Task {
                guard cliqueMembersVM.firstXMembers.count < min(cliqueNumMembers, 5) else { return }
                
                do {
                    try await cliqueMembersVM.fetchCliqueFirstXMembers(count: 5, total: cliqueNumMembers, userStore, cliqueStore)
                } catch {
                    presentToast(Toasts.somethingWentWrong)
                }
            }
        }
        .onDisappear {
            CollectionImagePrefetcher.instance.stopPrefetching(collectionId: collectionId)
        }
        .sheet(isPresented: $showCliqueMembers) {
            CliqueMembersListSheetView(cid: cid, fromFeed: true, userStore, cliqueStore)
                .presentationDetents([.fraction(0.35), .fraction(0.999)])
                .bottomSheetModifiers()
        }
        .onReceive(of: .refreshCollectionCells) { noti in
            guard noti.contains(collectionId) else { return }
            
            refresh()
        }
    }
}

// MARK: - Top Banner
extension CollectionFeedCellView {
    @ViewBuilder private func CollectionCellBanner() -> some View {
        HStack(spacing: 0) {
            if let collection, let clique = cliqueStore.cliques[collection.cliqueId] {
                if isInClique(cid: clique.id, cliqueStore) {
                    UserFeedHeader(
                        uid: collection.userId,
                        visibility: collection.visibility,
                        cliquePfp: clique.cliquePic
                    )
                    
                    NavigationLink(value: clique) {
                        CliquePill(clique.id, type: .feedCell)
                    }.noHighlight()
                } else {
                    CliqueFeedHeader(
                        clique: clique,
                        visibility: collection.visibility,
                        numFlicks: collection.numFlicks
                    )
                    
                    if !cliqueMembersVM.firstXMembers.isEmpty {
                        CliqueCircularMembersView(
                            members: cliqueMembersVM.firstXMembers,
                            memberLimit: 5,
                            type: .medium
                        )
                        .onHighPriorityTap {
                            showCliqueMembers.toggle()
                        }
                    }
                }
            }
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Card Stack
extension CollectionFeedCellView {
    @ViewBuilder private func SwipeableCardStack() -> some View {
        if let collection {
            if collection.images.count == 0 {
                Image("default-gradient")
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .frame(UIScreen.width - 32)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        if let clique = cliqueStore.cliques[collection.cliqueId], let relationship = clique.relationship, relationship.isInClique {
                            Text("Uploading flicks...")
                        } else {
                            Text("No images :(")
                        }
                    }
                    .padding(.top, -16)
            } else if imagesPgVM.items.isEmpty {
                LoadingStateView()
            } else {
                // lazy hstack doesn't load images behind because of offset stuff
                // adding content margins loads the second image behind but messes up when swiping
                VStack {
                    ScrollView(.horizontal) {
                        HStack(spacing: 0) {
                            ForEach(imagesPgVM.items, id: \.id) { cardID in
                                if let image = collectionImageStore.images[cardID.id] {
                                    CardCell(image)
                                }
                            }
                        }
                        .scrollTargetLayout()
//                        .if(.iOS17) { view in // scroll position without lazy hstack broken on ios 17
//                            view
                                .offsetX { value in
                                    let closestIndex = -Int(round(value / UIScreen.width))
                                    let newScrollPosition = imagesPgVM.items[closestIndex].id
                                    
                                    if scrollPosition != newScrollPosition {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            scrollPosition = newScrollPosition
                                        }
                                    }
                                }
//                        }
                    }
                    // cell works in clique hub, but then navigate to clique profile and try on that feed (only tested in collapsed mode because i had to scroll down) and something breaks with scroll position. so manually track with offsetX in both iOS 17 and 18!!!!!!!!! (this code is a mess lol)
//                    .scrollPosition(id: $scrollPosition)
                    .scrollTargetBehavior(.viewAligned)
                    .scrollIndicators(.hidden)
                    .padding(.vertical, -32)
                    // results in black screen idk man
//                    .onChange(of: clCoordinator.selectedImageId) { _, newValue in
//                        scrollPosition = newValue
//                    }
                }
            }
        }
    }
    
    @ViewBuilder private func CardCell(_ image: CollectionImage) -> some View {
        if let index = imagesPgVM.items.firstIndex(where: { $0.id == image.id }) {
            Group {
                if let selectedIndex = imagesPgVM.items.firstIndex(where: { $0.id == scrollPosition }),
                   abs(index - selectedIndex) <= 3
                {
                    CollectionPreviewSlideView(imageId: image.id, scrollPosition: scrollPosition, commentStore, userStore)
                    
                } else {
                    Color.clear
                        .frame(UIScreen.width - 32)
                }
            }
            .containerRelativeFrame(.horizontal)
            .scrollTransition { content, phase in
                content
                    .opacity(phase.isIdentity ? 1 : 0.9)
                    .scaleEffect(phase == .bottomTrailing || phase == .identity ? 1 : 0.5, anchor: .center)
            }
            .visualEffect { content, proxy in
                content
                    .scaleEffect(scale(proxy, scale: 0.5), anchor: .top)
                    .offset(x: minX(proxy, index: index))
                    .offset(y: -verticalOffset(proxy, totalHeight: 0))
            }
            .onAppear {
                // Prefetch images for smooth scrolling when this card becomes visible
                if let collection {
                    let imagesToPrefetch = Array(imagesPgVM.items.dropFirst(index).prefix(6))
                        .compactMap { collectionImageStore.images[$0.id] }

                    CollectionImagePrefetcher.instance.prefetchForContext(
                        .feedScroll,
                        collectionId: collection.id,
                        images: imagesToPrefetch
                    )
                }

                // Load next page when approaching end
                if imagesPgVM.size - (index + 1) % imagesPgVM.size == 2 || index == imagesPgVM.items.count - 1 {
                    Task {
                        await updateImages(.loadNextPage)
                    }
                }
            }
            .contentShape(.rect)
            .onTapGesture {
                clCoordinator.selectedImageId = image.id

                // Prefetch adjacent images for detail view
                if let collection, let currentIndex = imagesPgVM.items.firstIndex(where: { $0.id == image.id }) {
                    // Get 2 images before and 2 after current image
                    let startIndex = max(0, currentIndex - 2)
                    let endIndex = min(imagesPgVM.items.count - 1, currentIndex + 2)
                    let adjacentIds = Array(imagesPgVM.items[startIndex...endIndex])
                    let adjacentImages = adjacentIds.compactMap { collectionImageStore.images[$0.id] }

                    CollectionImagePrefetcher.instance.prefetchForContext(
                        .detailView,
                        collectionId: collection.id,
                        images: adjacentImages
                    )
                }

                showDetailView = true
            }
            .zIndex(-Double(index))
        }
    }
    
    @ViewBuilder private func EmptyStateView() -> some View {
        NothingHereYetView()
    }
    
    @ViewBuilder private func ErrorStateView() -> some View {
        SomethingWentWrong {
            clCoordinator.listState = .loading
            await updateImages(.refresh)
        }
        .padding(.horizontal, -16)
        .maxHeight()
    }
    
    @ViewBuilder private func LoadingStateView() -> some View {
        CliqueProgressView()
            .frame(UIScreen.width - 32)
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

// MARK: - Bottom
extension CollectionFeedCellView {
    /// Clique name, info pill, and caption
    @ViewBuilder private func BottomInfo() -> some View {
        if let collection {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    tabViewCoordinator.navigate(to: collection)
                    Task {
                        await FeedGalleryTip.navigationLinkTapEvent.donate()
                    }
                } label: {
                    HStack(spacing: 4) {
                        if collection.visibility == .priv {
                            IconImage("lock", color: .theme.iconPrimary, size: 16)
                        }
                        
                        Text(collection.name)
                            .font(.callout.weight(.semibold))
                            .multilineTextAlignment(.leading)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .textPrimary()
                        
                        IconImage("chevron-right", color: .theme.iconPrimary, size: 16)
                        
                        Text("• \(pluralizeWithCount(count: collection.numFlicks, singular: "flick"))")
                            .font(.footnote)
                            .textSecondary()
                        
                        Spacer()
                        
                        if isInClique(cid: collection.cliqueId, cliqueStore) {
                            // TODO: DRY
                            Menu {
                                Button {
                                    tabViewCoordinator.startCreateFlow(for: collection)
                                } label: {
                                    Text("Camera")
                                    Image("camera")
                                        .color(.theme.iconPrimary)
                                }
                                
                                Button {
                                    tabViewCoordinator.startCreateFlow(for: collection, shouldOpenLibrary: true)
                                } label: {
                                    Text("Library")
                                    Image("images-posts")
                                        .color(.theme.iconPrimary)
                                }
                            } label: {
                                SmallCTA(
                                    type: .primary,
                                    leadingIcon: "plus",
                                    text: "Add flicks"
                                )
                            }
                        } else {
                            Ellipsis()
                        }
                    }
                    .if(lastSeenVersion == AppConfig.currentVersion) { view in
                        // prevents tooltip from showing over whats new modal
                        view
                            .popoverTip(feedGalleryTip)
                    }
                    .maxWidth(.leading)
                    .contentShape(.rect)
                }.noHighlight()
                
                if !collection.description.isEmpty {
                    Text(collection.description)
                        .font(.footnote)
                        .textPrimary()
                }
                
                HStack {
                    Text("\(formatRelativeDate(collection.creation))")
                        .font(.caption2)
                        .textSecondary()
                    
                    if isInClique(cid: collection.cliqueId, cliqueStore) {
                        Spacer()
                        
                        Ellipsis()
                    }
                }
            }
        }
    }
    
    @ViewBuilder private func Ellipsis() -> some View {
        Menu {
            RefreshMenuButton {
                refresh()
            }
            
            ReportButton {
                showReportCover = true
            }
        } label: {
            IconImage("ellipsis", color: Color.theme.iconSecondary, size: 20)
        }
        .fullScreenCover(isPresented: $showReportCover) {
            ReportView(showReport: $showReportCover, objectId: collectionId, reportType: .collection)
        }
    }
    
    private func refresh() {
        // Cancel any existing refresh task
        refreshTask?.cancel()
        
        // Create new debounced refresh task
        refreshTask = Task {
            // Wait for debounce delay
            try? await Task.sleep(for: .seconds(0.3))
            
            // Check if task was cancelled
            guard !Task.isCancelled else { return }
            
            // Execute refresh
            await refreshAsync()
        }
    }
    
    private func refreshAsync() async {
        // Check if already refreshing
        guard !imagesPgVM.isRefreshing else { return }
        
        do {
            await CacheControl.shared.refreshCollection(collectionId)
          
            var updatedCollection = try await CollectionService.getCollectionById(.init(path: .init(collectionDataId: collectionId), query: .init(page: 0, size: 10, sort: mapFromSortOption(.likesDesc))))
            
            if imagesPgVM.sortOption == .likesDesc {
                updatedCollection.mostLikedImage = updatedCollection.images.first?.id
            }
            
            await updateImages(.refresh)
            
            collectionStore.updateCollection(updatedCollection, forceUpdateURL: true, collectionImageStore)
            
            // TODO: refresh comments (is it done somewhere else?)
//                await updateComments(.refresh)
        } catch {
            if !(error is CancellationError) {
                presentToast(Toasts.somethingWentWrong)
            }
        }
    }
    
    /// name and caption expandable text string
    @ViewBuilder private func NameAndCaption(_ markdown: String) -> some View {
        if let attrString = try? AttributedString(markdown: markdown) {
            Text(attrString) // TODO: fix expandable text
                .font(.footnote)
                .textPrimary()
                .maxWidth(.leading)
        }
    }
    
}

// MARK: - Helper functions
extension CollectionFeedCellView {
    private func checkIfSwipedPast(proxy: GeometryProxy, scrollViewWidth: CGFloat) {
        var minX = proxy.frame(in: .scrollView(axis: .horizontal)).minX
        minX = minX < 0 ? 0 : -minX
//        print(minX)
        if minX < -scrollViewWidth / 2 { // Adjust threshold if needed
            print("Last image swiped past") // Replace with actual action
        }
    }
    
    nonisolated private func progress(_ proxy: GeometryProxy, limit: CGFloat) -> CGFloat {
        let maxX = proxy.frame(in: .scrollView(axis: .horizontal)).maxX
        let width = proxy.bounds(of: .scrollView(axis: .horizontal))?.width ?? 0
        
        let progress = (maxX / width) - 1.0
        let cappedProgress = min(progress, limit)
        
        return cappedProgress
    }
    
    nonisolated private func scale(_ proxy: GeometryProxy, scale: CGFloat) -> CGFloat {
        let progress = progress(proxy, limit: 2)
        
        return 1 - (progress * 0.08)
        //this decimal adjusts the scaling of previews behind the image
    }
    
    nonisolated private func verticalOffset(_ proxy: GeometryProxy, totalHeight: CGFloat) -> CGFloat {
        let progress = progress(proxy, limit: 2)
        return progress * 4 // Adjust the multiplier for desired vertical offset
    }
    
    nonisolated private func minX(_ proxy: GeometryProxy, index: Int) -> CGFloat {
        let minX = proxy.frame(in: .scrollView(axis: .horizontal)).minX
        return minX < 0 ? 0 : -minX
    }
}

//#Preview {
//    ZoomContainer {
//        CollectionFeedCellView(collectionId: ClCollection.MOCK_COLLECTIONS[2].id)
//            .environment(TabViewCoordinator())
//            .primaryBackground()
//    }
//}
