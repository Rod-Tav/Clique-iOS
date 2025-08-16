//
//  ProfileCollectionsView.swift
//  Clique
//
//  Created by Rod Tavangar on 7/21/24.
//

import SwiftUI
import AdvancedList

struct UserProfileCollectionsView: View {
    @Environment(CollectionStore.self) private var collectionStore
    
    @Environment(AppCoordinator.self) private var appCoordinator
    
    @Environment(ProfileTabSwitcherCoordinator.self) private var profileTabSwitcherCoordinator
    @Environment(UserProfileViewModel.self) private var userProfileViewModel
    
    @State private var viewModel: UserCollectionsPaginationViewModel
    
    @State private var listState: ListState = .loading
    @State private var paginationState: AdvancedListPaginationState = .idle
    @State private var isScrollAtBottom: Bool = false
    
    private let uid: String
    
//    private var user: User {
//        userProfileViewModel.user
//    }
    
    init(uid: String, _ collectionStore: CollectionStore, _ collectionImageStore: CollectionImageStore) {
        self.uid = uid
        self.viewModel = .init(uid: uid, collectionStore, collectionImageStore)
    }
    
    var body: some View {
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
            refreshCollections()
        }
        .onChange(of: userProfileViewModel.triggerRefresh) {
            refreshCollections()
        }
        .bottomTabBarPadding()
    }
    
    private func refreshCollections() {
        Task {
            await CacheControl.shared.invalidate(patterns: ["/collection.*user/\(uid)"])
            await updateCollections(.refresh)
        }
    }
    
    @ViewBuilder
    private func CollectionList(collections: AdvancedList.Rows) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16, alignment: .top), count: 3), spacing: 16, content: collections)
//        ScrollView {
//            VStack(spacing: 0) {
//                LazyVStack(alignment: .leading, spacing: 16, content: collections)
                
//                CliqueProgressView()
//                    .opacity(paginationState == .loading ? 1 : 0)
//                    .onBecomingVisible {
//                        isScrollAtBottom = true
//                    }
//            }
//        }
//        .refreshable {
//            guard paginationState == .idle else { return }
//            viewModel.refreshing = true
//            await updateCollections(.refresh)
//            viewModel.refreshing = false
//        }
    }
    
    @ViewBuilder private func CollectionCell(_ collection: ClCollection) -> some View {
        NavigationLink(value: collection) {
            CollectionGridCell(collectionId: collection.id, cliqueId: collection.cliqueId)
        }
        .buttonStyle(.noHighlight)
        .disabled(profileTabSwitcherCoordinator.isScrolling)
        .disabled(appCoordinator.isHeaderPageScrolling)
    }
}

// MARK: Pagination state views
extension UserProfileCollectionsView {
    @ViewBuilder private func EmptyStateView() -> some View {
        NothingHereYetView()
//            .padding(.horizontal, 16)
//            .frame(maxHeight: .infinity)
    }
    
    @ViewBuilder private func ErrorStateView() -> some View {
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
            viewModel: viewModel,
            listState: $listState,
            paginationState: $paginationState,
            isScrollAtBottom: $isScrollAtBottom
        )
    }
}

//#Preview {
//    UserProfileCollectionsView(user: User.MOCK_USERS[0])
//}
