//
//  FeedView.swift
//  Clique
//
//  Created by Rod Tavangar on 6/9/24.
//

import SwiftUI
import AdvancedList

struct HomeFeedView: View {
    @Environment(AppCoordinator.self) private var appCoordinator
    @Environment(TabViewCoordinator.self) private var tabViewCoordinator
    
    @Environment(UserStore.self) private var userStore
    @Environment(CliqueStore.self) private var cliqueStore
    @Environment(CollectionStore.self) private var collectionStore
    @Environment(CommentStore.self) private var commentStore
    
    @State private var homeFeedPgVM: HomeFeedPaginationViewModel
    @State private var cliquesPgVM: UserCliquesPaginationViewModel
    
    //    @State private var showingHeader: Bool = true
    //    @State private var lastScrollPosition: CGFloat = 0
    @State private var headerSize: CGSize = .zero
    //    @State private var contentSize: CGSize = .zero
    //    @State private var scrollViewSize: CGSize = .zero
    //    @State private var turningPoint: CGFloat = .zero
    
    @State private var scrollID: String?
    
    @State private var listState: ListState = .loading
    @State private var paginationState: AdvancedListPaginationState = .idle
    @State private var isScrollAtBottom: Bool = false
    
    @State private var cliqueListState: ListState = .loading
    @State private var cliquePaginationState: AdvancedListPaginationState = .idle
    @State private var isCliqueScrollAtRight: Bool = false
    
    @State private var showAddFriendsSheet: Bool = false
    
    init(_ collectionStore: CollectionStore, _ collectionImageStore: CollectionImageStore, _ userStore: UserStore, _ cliqueStore: CliqueStore) {
        self.homeFeedPgVM = .init(collectionStore, collectionImageStore, userStore, cliqueStore)
        self.cliquesPgVM = .init(uid: userStore.currentUserId ?? "", cliqueStore)
    }
    
    var body: some View {
        @Bindable var bindableTVC = tabViewCoordinator
        
        TabNavigationStack(path: $bindableTVC.collectionsNavigationPath) {
            //            ZStack(alignment: .top) {
            //                if showingHeader {
            VStack(spacing: 0) {
                Header()
                //                    .primaryBackground()
                //                        .opacity(0.5)
                //                    .zIndex(1)
                //                        .transition(
                //                            .asymmetric(
                //                                insertion: .move(edge: .top).combined(with: .opacity),
                //                                removal: .move(edge: .top).combined(with: .opacity)
                //                            )
                //                        )
                //                }
                
                //                ScrollView {
                //                    VStack(spacing: 0) {
                //                        Rectangle()
                //                            .fill(.clear)
                //                            .frame(1)
                //                            .id("TOP")
                
                //                        CliqueHubCarousel()
                
                AdvancedList(homeFeedPgVM.items, listView: { rows in
                    FeedList(rows: rows)
                }, content: { feedItem in
                    FeedItemCellView(feedItem: feedItem)
                }, listState: listState, emptyStateView: {
                    EmptyStateView()
                }, errorStateView: { _ in
                    ErrorStateView()
                }, loadingStateView: {
                    LoadingStateView()
                })
                .pagination(.init(type: .lastItem, shouldLoadNextPage: { Task { await updateHomeFeed(.loadNextPage) } }){ })
                .maxHeight()
                .onAppear {
                    Task {
                        guard listState == .loading else { return }
                        await updateHomeFeed(.loadFirstPage)
                    }
                }
                //                    }
                //                }
                //                .scrollTo(id: $scrollID)
                //                .allowsHitTesting(!(homeFeedPgVM.refreshing || (paginationState == .loading && isScrollAtBottom)))
                //                .onChange(of: tabViewCoordinator.triggerScrollToTopOfFeed) {
                //                    isScrollAtBottom = false
                //                    scrollID = "TOP"
                //                }
                //                .contentMargins(.top, headerSize.height)
                //                .scrollIndicators(.hidden)
                //                .bottomTabBarPadding()
            }
            .bottomTabBarPadding()
            .primaryBackground()
            // ProMotion-optimized spring animation (120Hz)
            .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.86, blendDuration: 0.25), value: listState)
            .refreshable {
                guard paginationState == .idle else { return }
                homeFeedPgVM.refreshing = true
                
                // Clear cache for home feed before refreshing
                await CacheControl.shared.refreshHomeFeed()
                
                trigger(.refreshCollectionCells, object: homeFeedPgVM.items.compactMap(\.collection?.id))
                
                //                homeFeedPgVM.items
                //                    .compactMap(\.collection?.id)
                //                    .forEach { collectionStore.collections.removeValue(forKey: $0) }
                
                DispatchQueue.main.async { // no idea
                    Task {
                        async let updateFeed: () = await updateHomeFeed(.refresh)
                        async let updateCliques: () = await updateCliques(.refresh)
                        
                        _ = await (updateFeed, updateCliques)
                    }
                }
                
                homeFeedPgVM.refreshing = false
            }
            .onReceive(of: .refreshHomeFeed) { _ in
                Task {
                    await updateHomeFeed(.refresh)
                }
            }
        }
        .sheet(isPresented: $showAddFriendsSheet) {
            AddContactsView()
                .bottomSheetModifiers()
        }
    }
    
    @ViewBuilder private func Header() -> some View {
        VStack(spacing: 0) {
            TopAppBar(
                type: .medium,
                leadingIcon: { },
                header: {
                    HStack(alignment: .top, spacing: 0) {
                        Text("Clique")
                            .font(Font.custom("NewakeDemo", size: 24))
                            .textPrimary()
                        
                        IconImage("clique-star", color: Color.theme.cliquePink, size: 8)
                    }
                },
                trailingIcon: {
                    NavigationLink(value: "NotificationsCenter") {
                        IconImage("inbox", color: .theme.iconPrimary, size: 24)
                            .overlayTopRightNotification(when: tabViewCoordinator.hasNotification)
                    }
                }
            )
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            
            //            Divider()
            //                .background(Color.theme.strokeTertiary)
        }
        //        .getSize { size in
        //            headerSize = size
        //        }
    }
    
    @ViewBuilder private func FeedList(rows: AdvancedList.Rows) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // for scroll to top
                Rectangle()
                    .fill(.clear)
                    .frame(1)
                    .id("TOP")
                
                LazyVStack(spacing: 16, content: rows)
                    .padding(.top, -1)
                
                CliqueProgressView()
                    .opacity(paginationState == .loading ? 1 : 0)
                    .onBecomingVisible {
                        isScrollAtBottom = true
                    }
                
                //                Text("You reached the bottom!")
                //                    .padding(.top, -24)
                //                    .opacity(viewModel.done ? 1 : 0)
            }
            //            .id(UUID()) // sizing issue on refresh
            //            .padding(.bottom, 12)
        }
        .scrollTo(id: $scrollID)
        .allowsHitTesting(!(homeFeedPgVM.refreshing || (paginationState == .loading && isScrollAtBottom)))
        .onReceive(of: .scrollToTopOfFeed) { _ in
            isScrollAtBottom = false
            scrollID = "TOP"
        }
        .contentMargins(.top, headerSize.height)
        .scrollIndicators(.hidden)
        //        .clipShape(.rect) // clip to safe area. if we don't do this, then hide status bar. helps with refresh sizing issue
    }
    
    // TODO: top bar hiding logic in FeedList
    //    @ViewBuilder
    //    private func Feed(rows: @escaping AdvancedList.Rows) -> some View {
    //        ScrollViewReader { reader in
    //            ScrollView {
    //                LazyVStack(spacing: 0) {
    //                    // place content under header
    ////                    Header()
    ////                        .hidden()
    //
    //                        LazyVStack(spacing: 16) {
    //                            if viewModel.feedItems.isEmpty {
    //                                Text("Empty")
    //                            } else {
    //                                ForEach(viewModel.feedItems) { item in
    //                                        CollectionCellView(collection: collection)
    //                                }
    //                            }
    //                        }
    ////
    ////                    switch viewModel.fetchState {
    ////                    case .loadingNextPage:
    ////                        CliqueProgressView()
    ////                    case .loaded:
    ////                        CliqueProgressView()
    ////                            .onAppear { Task { await viewModel.fetchNextPage() } }
    ////                    default:
    ////                        EmptyView()
    ////                    }
    //
    //
    //                }
    //                .id("content")
    //                .offsetY { value in
    //                    // prevent changing on bounce
    //                    guard value < 0, -value + scrollViewSize.height < contentSize.height else { return }
    //
    //                    if (showingHeader && value > lastScrollPosition) || (!showingHeader && value < lastScrollPosition) {
    //                        turningPoint = value
    //                    }
    //                    if (showingHeader && (turningPoint - value) > 10) || // going down
    //                        (!showingHeader && (value - turningPoint) > 75) { // going up
    //                        showingHeader = value > turningPoint
    //                    }
    //
    //                    lastScrollPosition = value
    //                }
    //                .sizeReader(size: $contentSize)
    //                .onChange(of: tabViewCoordinator.triggerScrollToTopOfFeed) {
    //                    withAnimation {
    //                        reader.scrollTo("content", anchor: .top)
    //                    }
    //                }
    //            }
    //            .clipShape(.rect) // clip to safe area. if we don't do this, then hide status bar
    //            .getSize { size in
    //                scrollViewSize = size
    //            }
    //            .scrollIndicators(.hidden)
    //        }
    //    }
}

// MARK: Pagination state views
extension HomeFeedView {
    @ViewBuilder private func EmptyStateView() -> some View {
        VStack(spacing: 16) {
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
                Task {
                    await updateHomeFeed(.refresh)
                }
            }
        }
        .infiniteFrame()
    }
    
    @ViewBuilder private func ErrorStateView() -> some View {
        SomethingWentWrong {
            listState = .loading
            await updateHomeFeed(.refresh)
        }
        //        .padding(.top, headerSize.height)
    }
    
    @ViewBuilder private func LoadingStateView() -> some View {
        CliqueProgressView()
            .infiniteFrame()
    }
    
    func updateHomeFeed(_ operation: PaginationOperationType) async {
        await PaginationHelper.updateItems(
            operation,
            viewModel: homeFeedPgVM,
            listState: $listState,
            paginationState: $paginationState,
            isScrollAtBottom: $isScrollAtBottom
        )
    }
}

// MARK: - Carousel
extension HomeFeedView {
    @ViewBuilder private func CliqueHubCarousel() -> some View {
        VStack(spacing: 12) {
            Divider()
            
            Text("My Cliques")
                .font(.footnote.bold())
                .textSecondary()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
            
            CliqueHubCliques()
                .padding(.bottom, 4)
            
            Divider()
        }
        //        .overlay(
        //            Rectangle()
        //                .inset(by: 0.5)
        //                .stroke(.tertiaryStroke, lineWidth: 1)
        //                .frame(maxHeight: .infinity, alignment: .bottom)
        //        )
    }
    
    @ViewBuilder private func CliqueHubCliques() -> some View {
        AdvancedList(cliquesPgVM.items, listView: { rows in
            CliqueList(cliques: rows)
        }, content: { cliqueID in
            if let clique = cliqueStore.cliques[cliqueID] {
                CliqueCell(clique: clique)
            }
        }, listState: cliqueListState, emptyStateView: {
            CliquesEmptyStateView()
        }, errorStateView: { _ in
            CliquesErrorStateView()
        }, loadingStateView: {
            CliquesLoadingStateView()
        })
        .pagination(.init(type: .lastItem, shouldLoadNextPage: { Task { await updateCliques(.loadNextPage) } }) { })
        .onAppear {
            Task {
                guard cliqueListState == .loading else { return }
                await updateCliques(.loadFirstPage)
            }
        }
        .maxWidth()
    }
    
    @ViewBuilder private func CliqueList(cliques: AdvancedList.Rows) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 16, content: cliques)
        }
        .fixedSize(horizontal: false, vertical: true)
        .contentMargins(.horizontal, 16)
        .scrollIndicators(.hidden)
    }
    
    @ViewBuilder private func CliqueCell(clique: Clique) -> some View {
        NavigationLink(value: clique) {
            VStack(spacing: 6) {
                CliquePfpAsyncView(pfp: clique.cliquePic, type: .small, quality: .medium)
                
                Text(clique.name)
                    .textPrimary()
                    .font(.caption)
                    .lineLimit(1)
                    .frame(maxWidth: CliquePfpViewType.small.size.width * 2)
            }
        }.buttonStyle(.noHighlight)
    }
    
    @ViewBuilder private func CliquesEmptyStateView() -> some View {
        NothingHereYetView()
        //            .padding(16)
        //            .frame(maxHeight: .infinity)
    }
    
    @ViewBuilder private func CliquesErrorStateView() -> some View {
        SomethingWentWrong {
            cliqueListState = .loading
            await updateCliques(.refresh)
        }
        //        .padding(.top, headerSize.height)
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder private func CliquesLoadingStateView() -> some View {
        CliqueProgressView()
        //            .frame(maxHeight: .infinity)
    }
    
    private func updateCliques(_ operation: PaginationOperationType) async {
        await PaginationHelper.updateItems(
            operation,
            viewModel: cliquesPgVM,
            listState: $cliqueListState,
            paginationState: $cliquePaginationState,
            isScrollAtBottom: $isCliqueScrollAtRight
        )
    }
}

//#Preview {
//    ZoomContainer {
//        FeedView()
//            .environment(TabViewCoordinator())
//            .environment(FeedViewModel())
//    }
//}
