import SwiftUI
import AdvancedList

struct CliqueRecentsView: View {
    @Environment(\.safeAreaInsets) private var safeAreaInsets
    
    @Environment(CliqueStore.self) private var cliqueStore
    @Environment(CollectionStore.self) private var collectionStore
    
    @Environment(AppCoordinator.self) private var appCoordinator
    @Environment(TabViewCoordinator.self) private var tabViewCoordinator
   
    @Environment(CliqueProfileViewModel.self) private var profileViewModel
    @Environment(ProfileTabSwitcherCoordinator.self) private var profileTabSwitcherCoordinator
    

    @State private var cliqueFeedPgVM: CliqueFeedPaginationViewModel
    
    
//    @State private var bounds: [String: CGRect] = [:]
//    @State private var tapped: Bool = false
    
    // zoom transition animation, can't crop screen
//    private func getPercentage(geo: GeometryProxy) -> Void {
//        let centerX = UIScreen.width / 2
//        let imageX = geo.frame(in: .global).midX
//        
//        let centerY = UIScreen.height / 2
//        let imageY = geo.frame(in: .global).midY
//        
//        let width = UIScreen.width
//        let imageWidth = geo.frame(in: .global).width
//        
//        let scaleFactor = imageWidth / width
//        
//        tabViewCoordinator.animation = .mainZoom(
//            xOffset: imageX - centerX,
//            yOffset: -(centerY - imageY) + safeAreaInsets.top + safeAreaInsets.bottom,
//            scaleFactor: scaleFactor * (1 + scaleFactor)
//        )
//    }
    
    @State private var listState: ListState = .loading
    @State private var paginationState: AdvancedListPaginationState = .idle
    @State private var isScrollAtBottom: Bool = false
    
    let cid: String
    
    private var clique: Clique? {
        cliqueStore.cliques[cid]
    }
    
    init(cid: String, _ collectionStore: CollectionStore, _ collectionImageStore: CollectionImageStore, _ userStore: UserStore, _ cliqueStore: CliqueStore) {
        self.cid = cid
        self.cliqueFeedPgVM = .init(cid: cid, collectionStore, collectionImageStore, userStore, cliqueStore)
    }
    
    var body: some View {
//            LazyVGrid(columns: columns, spacing: 3) {
//                ForEach(1 ..< 10) { _ in
//                    ForEach(Post.MOCK_POSTS, id: \.self) { post in
//                        AppNavigationLink {
//                            SinglePostView(post: post)
////                                .viewExtractor { view in
////                                    view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
////                                }
//                        } label: {
//                            GeometryReader { geo in
//                                GridImageView(post.imageUrls[0])
//                                // when scrolling, tap to stop triggers this
////                                    .simultaneousGesture(TapGesture().onEnded {
////                                        print("here")
////                                        getPercentage(geo: geo)
////                                        //                                        calculateAndApplyOffsets(id: post.id)
////                                    })
//                            }
//                            .aspectRatio(1, contentMode: .fill)
//                        }
//                        .disabled(profileTabSwitcherCoordinator.isScrolling)
//                    }
//                }
//            }
        
        AdvancedList(cliqueFeedPgVM.items, listView: { rows in
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
        .pagination(.init(type: .lastItem, shouldLoadNextPage: { Task { await updateCliqueRecents(.loadNextPage) } }) { })
        .onAppear {
            Task {
                guard listState == .loading else { return }
                await updateCliqueRecents(.loadFirstPage)
            }
        }
        
//                    .enableFullSwipePop(true)
        .primaryBackground()
//        .onAppear {
//            DispatchQueue.main.async {
//                tabViewCoordinator.animation = Constants.mainTransition
//            }
//        }
        .onChange(of: profileViewModel.triggerRefresh) {
//            let oldCount = cliqueFeedPgVM.items.count
            
//            cliqueFeedPgVM.items
//                .compactMap(\.collection?.id)
//                .forEach { collectionStore.collections.removeValue(forKey: $0) }
            
            trigger(.refreshCollectionCells, object: cliqueFeedPgVM.items.compactMap(\.collection?.id))
            
            Task {
                // Clear cache for clique feed
                await CacheControl.shared.invalidate(patterns: ["/feed.*clique/\(cid)"])
                await updateCliqueRecents(.refresh)
                
//                if oldCount == cliqueFeedPgVM.items.count {
//                    await updateCliqueRecents(.refresh)
//                }
            }
        }
        .bottomTabBarPadding()
    }
    
    @ViewBuilder private func FeedList(rows: AdvancedList.Rows) -> some View {
//        ScrollView {
            VStack(spacing: 0) {
                LazyVStack(spacing: 16, content: rows)

                CliqueProgressView()
                    .opacity(paginationState == .loading ? 1 : 0)
                    .onBecomingVisible {
                        isScrollAtBottom = true
                    }
            }
            .frameTop()
//            .allowsHitTesting(!(viewModel.refreshing || (paginationState == .loading && isScrollAtBottom)))
//            .refreshable {
//                guard paginationState == .idle else { return }
//                viewModel.refreshing = true
//                await updateRecents(.refresh)
//                viewModel.refreshing = false
//            }
            .disabled(profileTabSwitcherCoordinator.isScrolling)
            .disabled(appCoordinator.isHeaderPageScrolling)
//        }
    }
}

// MARK: Pagination state views
extension CliqueRecentsView {
    @ViewBuilder private func EmptyStateView() -> some View {
        if let clique, let relationship = clique.relationship, relationship.isInClique {
            NothingHereYetAddFlicksView(clique: clique)
        } else {
            NothingHereYetView()
        }
    }
    
    @ViewBuilder private func ErrorStateView() -> some View {
        SomethingWentWrong {
            listState = .loading
            await updateCliqueRecents(.refresh)
        }
//        .padding(.top, headerSize.height)
        .padding(.horizontal, 16)
        .frame(maxHeight: .infinity)
    }
    
    @ViewBuilder private func LoadingStateView() -> some View {
        CliqueProgressView()
            .infiniteFrame()
    }
    
    private func updateCliqueRecents(_ operation: PaginationOperationType) async {
        await PaginationHelper.updateItems(
            operation,
            viewModel: cliqueFeedPgVM,
            listState: $listState,
            paginationState: $paginationState,
            isScrollAtBottom: $isScrollAtBottom
        )
    }
}


#Preview {
    CliqueProfileView(cid: Clique.MOCK_CLIQUES[4].id)
        .environment(TabViewCoordinator())
}
