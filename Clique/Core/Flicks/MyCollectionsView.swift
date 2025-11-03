//
//  MyCollectionsView.swift
//  Clique
//
//  Created by Rod Tavangar on 3/26/25.
//

import SwiftUI
import AdvancedList

private enum CollectionsViewType: String {
    case grid, list, compactList
    
    var icon: String {
        switch self {
        case .grid: "list"
        case .list: "collections"
        case .compactList: "posts"
        }
    }
}

struct MyCollectionsView: View {
    @AppStorage("MyCollectionsViewType") private var viewType: CollectionsViewType = .compactList
    
    @Environment(\.safeAreaInsets) private var safeAreaInsets
    
    @Environment(UserStore.self) private var userStore
    @Environment(CollectionStore.self) private var collectionStore
    @Environment(CollectionImageStore.self) private var collectionImageStore
    
    @Environment(AppCoordinator.self) private var appCoordinator
    @Environment(TabViewCoordinator.self) private var tabViewCoordinator
    
    @State private var viewModel: UserCollectionsPaginationViewModel
    
    @State private var listState: ListState = .loading
    @State private var paginationState: AdvancedListPaginationState = .idle
    @State private var isScrollAtBottom: Bool = false
    
    @State private var scrollID: String?
    
    @State private var showCliqueCreator: Bool = false
        
    init(uid: String, _ collectionStore: CollectionStore, _ collectionImageStore: CollectionImageStore) {
        self.viewModel = .init(uid: uid, collectionStore, collectionImageStore)
    }
    
    var body: some View {
        @Bindable var bindableVM = tabViewCoordinator
        
        TabNavigationStack(path: $bindableVM.collectionsNavigationPath) {
            VStack(spacing: 0) {
                TopBar()
                
                VStack(spacing: 12) {
                    HStack {
                        Text("My Collections")
                            .font(.footnote.bold())
                            .textSecondary()
                        
                        Spacer()
                        
                        Button {
                            if viewType == .compactList {
                                viewType = .grid
                            } else {
                                viewType = .compactList
                            }
                        } label: {
                            IconImage(viewType.icon, color: .theme.iconPrimary, size: 16)
                        }.noHighlight()
                    }
                    .padding(.top, 12)
                    
                    // TODO: DRY
                    AdvancedList(viewModel.items, listView: { collections in
                        CollectionList(collections: collections)
                    }, content: { collectionID in
                        if let collection = collectionStore.collections[collectionID] {
                            CollectionCell(collection)
                        }
                    }, listState: listState, emptyStateView: {
                        EmptyStateView()
                    }, errorStateView: { _ in
                        ErrorStateView()
                    }, loadingStateView: {
                        LoadingStateView()
                    })
                    .pagination(.init(type: .lastItem, shouldLoadNextPage: { Task { await updateCollections(.loadNextPage) } }) { })
                    .frameTop()
                    .onAppear {
                        Task {
                            guard listState == .loading else { return }
                            await updateCollections(.loadFirstPage)
                        }
                    }
                    .onReceive(of: .refreshUserCollections) { _ in
                        Task { await updateCollections(.refresh) }
                    }
                }
                .padding(.horizontal, 16)
            }
            .bottomTabBarPadding()
            .padding(.bottom, 24)
            .primaryBackground()
        }
    }
    
    @ViewBuilder private func TopBar() -> some View {
        TopAppBar(
            type: .medium,
            leadingIcon: { },
            header: {
                HStack(alignment: .top, spacing: 0) {
                    Text("Flicks")
                        .font(Font.custom("NewakeDemo", size: 24))
                        .textPrimary()
                    
                    IconImage(name: "clique-star", color: Color.theme.cliquePink, size: 8)
                }
            },
            trailingIcon: {
                HStack(spacing: 8) {
                    //                        Button {
                    //                            showAddFriendsSheet = true
                    //                        } label: {
                    //                            IconImage(name: "add-user", color: .theme.iconPrimary, size: 24)
                    //                        }.buttonStyle(.noHighlight)
                    
                    Menu {
                        Button {
                            showCliqueCreator = true
                        } label: {
                            Text("Create Clique")
                            Image("3-user")
                                .color(.theme.iconPrimary)
                        }
                        
                        Button {
                            tabViewCoordinator.createFlowMode = .library
                            tabViewCoordinator.selectTab(.create)
                            trigger(.openLibrary)
                        } label: {
                            Text("Upload From Library")
                            Image("images-posts")
                                .color(.theme.iconPrimary)
                        }
                        
                        Button {
                            tabViewCoordinator.createFlowMode = .camera
                            tabViewCoordinator.selectTab(.create)
                        } label: {
                            Text("Camera")
                            Image("camera")
                                .color(.theme.iconPrimary)
                        }
                    } label: {
                        IconImage(name: "plus", color: .theme.iconPrimary, size: 24)
                    }
                    
                    NavigationLink(value: "Search") {
                        IconImage(name: "search", color: .theme.iconPrimary, size: 24)
                    }
                    
                    NavigationLink(value: "CurrentUser") {
                        UserPfpAsyncView(pfp: userStore.currentUser?.profilePic, size: 24, quality: .low)
//                            .overlay(alignment: .topTrailing) {
//                                if tabViewCoordinator.hasInboxNotifcation {
//                                    Circle()
//                                        .fill(Color.theme.strokeBgMatch)
//                                        .frame(8 + 2)
//                                        .overlay {
//                                            Circle()
//                                                .fill(Color.theme.red)
//                                                .frame(8)
//                                        }
//                                        .offset(x: 2, y: -2)
//                                }
//                            }
                    }
                    .padding(.leading, 4)
                }
            }
        )
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        
        Divider()
            .background(Color.theme.strokeTertiary)
    }
}

extension MyCollectionsView {
    @ViewBuilder private func CollectionList(collections: AdvancedList.Rows) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(.clear)
                    .frame(1)
                    .id("TOP")
                
                ZStack(alignment: .top) {
                    LazyVStack(spacing: 16, content: collections)
                        .opacity(viewType == .compactList ? 1 : 0)
                    
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 16, alignment: .top), count: 3),
                        spacing: 16,
                        content: collections
                    )
                    .opacity(viewType == .grid ? 1 : 0)
                }
            }
        }
        .scrollTo(id: $scrollID)
        .scrollBarIgnorePadding(16)
        .refreshable {
            guard paginationState == .idle else { return }
            
            // Clear cache for user's collections
            if let userId = userStore.currentUserId {
                await CacheControl.shared.invalidate(patterns: ["/collection.*user/\(userId)"])
            }
            
            await updateCollections(.refresh)
        }
//        .onReceive(of: .scrollToTopOfMyCollections) { _ in
//            isScrollAtBottom = false
//            scrollID = "TOP"
//        }
    }
    
    @ViewBuilder private func CollectionCell(_ collection: ClCollection) -> some View {
        NavigationLink(value: collection) {
            if viewType == .compactList {
                HStack(spacing: 16) {
                    // TODO: DRY(?)
                    CollectionPreviewWithGridBg(width: 64) {
                        if let coverPhoto = collection.coverPhoto {
                            ProfileCollectionCoverPhotoAsyncImage(urls: coverPhoto, side: 64, quality: .low)
                        } else if let mostLikedImage = collection.mostLikedImage, let urls = collectionImageStore.images[mostLikedImage]?.imageUrl {
                            ProfileCollectionCoverPhotoAsyncImage(urls: urls, side: 64, quality: .low)
                        } else {
                            ProfileCollectionPlaceholder(side: 64)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        CliquePill(collection.cliqueId, type: .collectionPreview)
                        
                        Text(collection.name)
                            .lineLimit(1)
                            .font(.footnote.bold())
                            .textPrimary()

                        HStack(spacing: 8) {
                            Pill(icon: "calendar", text: formatDateMdyy(collection.creation))

                            Pill(icon: "images-posts", text: formatNumber(collection.displayFlickCount(currentUserId: userStore.currentUserId)))
                        }
                    }
                }
                .maxWidth(.leading)
                .contentShape(.rect)
            } else {
                CollectionGridCell(collectionId: collection.id, cliqueId: collection.cliqueId)
            }
            
        }
        .buttonStyle(.noHighlight)
    }
    
    // MARK: Pagination state views
    @ViewBuilder
    private func EmptyStateView() -> some View {
        NothingHereYetView()
        //            .padding(.horizontal, 16)
        //            .frame(maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func ErrorStateView() -> some View {
        SomethingWentWrong {
            listState = .loading
            await updateCollections(.refresh)
        }
        .padding(.horizontal, 16)
        .frame(maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func LoadingStateView() -> some View {
        CliqueProgressView()
            .infiniteFrame()
    }
    
    private func updateCollections(_ operation: PaginationOperationType) async {
        await PaginationHelper.updateItems(
            operation,
            viewModel: viewModel,
            listState: $listState,
            paginationState: $paginationState,
            isScrollAtBottom: $isScrollAtBottom
        )
    }
}
