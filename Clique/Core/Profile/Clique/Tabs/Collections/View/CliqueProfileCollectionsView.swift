//
//  CliqueProfileCollectionsView.swift
//  Clique
//
//  Created by Rod Tavangar on 7/12/24.
//

import SwiftUI
import AdvancedList

struct CliqueProfileCollectionsView: View {
    @Environment(AppCoordinator.self) private var appCoordinator
    
    @Environment(CliqueStore.self) private var cliqueStore
    @Environment(CollectionStore.self) private var collectionStore
    
    @Environment(CliqueProfileViewModel.self) private var profileViewModel
    @Environment(ProfileTabSwitcherCoordinator.self) private var profileTabSwitcherCoordinator
   
    @State private var collectionsPgVM: CliqueCollectionsPaginationViewModel
    
    @State private var listState: ListState = .loading
    @State private var paginationState: AdvancedListPaginationState = .idle
    @State private var isScrollAtBottom: Bool = false
    
    let cid: String
    
    init(cid: String, _ collectionStore: CollectionStore, _ collectionImageStore: CollectionImageStore) {
        self.cid = cid
        self.collectionsPgVM = .init(cid: cid, collectionStore, collectionImageStore)
    }
    
    // MARK: - Body
    var body: some View {
        AdvancedList(collectionsPgVM.items, listView: { collections in
            CollectionList(collections: collections)
        }, content: { collectionID in
            if let collection = collectionStore.collections[collectionID] {
                CollectionCell(collection: collection)
            }
        }, listState: listState, emptyStateView: {
            EmptyStateView()
        }, errorStateView: { _ in
            ErrorStateView()
        }, loadingStateView: {
            LoadingStateView()
        })
        .pagination(.init(type: .lastItem, shouldLoadNextPage: { Task { await updateCollections(.loadNextPage) } }) { EmptyView() })
        .frameTop()
        .onAppear {
            Task {
                guard listState == .loading else { return }
                await updateCollections(.loadFirstPage)
            }
        }
        .onChange(of: profileViewModel.triggerRefresh) { _, _ in
            Task {
                // Check if already refreshing before triggering new refresh
                guard !collectionsPgVM.isRefreshing else { return }

                // Clear cache for clique collections
                await CacheControl.shared.invalidate(patterns: ["/collection.*clique/\(cid)"])
                await updateCollections(.refresh)
                
                // Add a small delay for debouncing
                try? await Task.sleep(for: .seconds(0.3))
                
                // Check again after delay
                guard !collectionsPgVM.isRefreshing else { return }
                await updateCollections(.refresh)
            }
        }
        .padding(.bottom, 16)
        .bottomTabBarPadding()
//        safeAreaInsets.bottom - Constants.collectionPreviewGridBgHeight
    }
    
    @ViewBuilder private func CollectionList(collections: AdvancedList.Rows) -> some View {
        
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16, alignment: .top), count: 3), spacing: 16, content: collections)
        
//        VStack(spacing: 0) {
//            LazyVStack(spacing: 24, content: collections)
            
//            CliqueProgressView()
//                .opacity(paginationState == .loading ? 1 : 0)
//                .onBecomingVisible {
//                    isScrollAtBottom = true
//                }
//        }
//        .offset(y: Constants.collectionPreviewGridBgHeight)
//            .fullScreenCover(item: $presentedItem) { item in
//                NavigationStack {
//                    CollectionContentView(collection: item)
//                        .presentationDetents([.fraction(0.999)])
//                }
//                .navigationTransition(.zoom(sourceID: item, in: namespace))
//            }
    }
    
    @ViewBuilder private func CollectionCell(collection: ClCollection) -> some View {
        NavigationLink(value: collection) {
            CollectionGridCell(collectionId: collection.id)
        }
        .buttonStyle(.noHighlight)
        .disabled(profileTabSwitcherCoordinator.isScrolling)
        .disabled(appCoordinator.isHeaderPageScrolling)
    }
}

// MARK: Pagination state views
extension CliqueProfileCollectionsView {
    @ViewBuilder private func EmptyStateView() -> some View {
        NothingHereYetView()
//            .padding(.horizontal, 16)
//            .frame(maxHeight: .infinity)
    }
    
    @ViewBuilder  private func ErrorStateView() -> some View {
        SomethingWentWrong {
            listState = .loading
            await updateCollections(.refresh)
        }
        .padding(.horizontal, 16)
        .frame(maxHeight: .infinity)
    }
    
    @ViewBuilder private func LoadingStateView() -> some View {
        CliqueProgressView()
            .infiniteFrame()
    }
    
    private func updateCollections(_ operation: PaginationOperationType) async {
        await PaginationHelper.updateItems(
            operation,
            viewModel: collectionsPgVM,
            listState: $listState,
            paginationState: $paginationState,
            isScrollAtBottom: $isScrollAtBottom
        )
    }
}

#Preview {
    CliqueProfileCollectionsView(cid: Clique.MOCK_CLIQUES[0].id, CollectionStore(), CollectionImageStore())
}
