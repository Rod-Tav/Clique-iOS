//
//  UserCliquesView.swift
//  Clique
//
//  Created by Rod Tavangar on 1/31/25.
//

import SwiftUI
import AdvancedList

struct UserCliquesView: View {
    @Environment(CliqueStore.self) private var cliqueStore
    
    @Environment(AppCoordinator.self) private var appCoordinator
    @Environment(UserProfileViewModel.self) private var userProfileViewModel
    @Environment(ProfileTabSwitcherCoordinator.self) private var profileTabSwitcherCoordinator
//    @Environment(InboxCoordinator.self) private var inboxCoordinator
    
    @State private var viewModel: UserCliquesPaginationViewModel
    
    @State private var listState: ListState = .loading
    @State private var paginationState: AdvancedListPaginationState = .idle
    @State private var isScrollAtBottom: Bool = false
    
    private let uid: String
    
    init(uid: String, _ cliqueStore: CliqueStore) {
        self.uid = uid
        self.viewModel = .init(uid: uid, cliqueStore)
    }
    
    var body: some View {
        AdvancedList(viewModel.items, listView: { cliques in
            CliqueList(cliques)
        }, content: { cliqueID in
            if let clique = cliqueStore.cliques[cliqueID] {
                CliqueCell(clique)
            }
        }, listState: listState, emptyStateView: {
            EmptyStateView()
        }, errorStateView: { _ in
            ErrorStateView()
        }, loadingStateView: {
            LoadingStateView()
        })
        .pagination(.init(type: .lastItem, shouldLoadNextPage: { Task { await updateCliques(.loadNextPage) } }) { })
        .onAppear {
            Task {
                guard listState == .loading else { return }
                await updateCliques(.loadFirstPage)
            }
        }
        .onReceive(of: .refreshUserCliques) { _ in
            refreshCliques()
        }
        .onChange(of: userProfileViewModel.triggerRefresh) {
            refreshCliques()
        }
        .bottomTabBarPadding()
    }
    
    private func refreshCliques() {
        Task {
            await CacheControl.shared.invalidate(patterns: ["/clique.*user/\(uid)"])
            await updateCliques(.refresh)
        }
    }
    
    @ViewBuilder private func CliqueList(_ cliques: AdvancedList.Rows) -> some View {
//        ScrollView {
            VStack(spacing: 0) {
                LazyVStack(spacing: 16, content: cliques)
                
                CliqueProgressView()
                    .opacity(paginationState == .loading ? 1 : 0)
                    .onBecomingVisible {
                        isScrollAtBottom = true
                    }
            }
            .frameTop()
//        }
//        .refreshable {
//            guard paginationState == .idle else { return }
//            viewModel.refreshing = true
//            await updateCliques(.refresh)
//            viewModel.refreshing = false
//        }
    }
    
    @ViewBuilder private func CliqueCell(_ clique: Clique) -> some View {
        NavigationLink(value: clique) {
            CliqueListCellView(cid: clique.id)
        }
        .buttonStyle(.noHighlight)
        .disabled(profileTabSwitcherCoordinator.isScrolling)
        .disabled(appCoordinator.isHeaderPageScrolling)
    }
}

// MARK: Pagination state views
extension UserCliquesView {
    @ViewBuilder private func EmptyStateView() -> some View {
        NothingHereYetView()
//            .padding(.horizontal, 16)
//            .frame(maxHeight: .infinity)
    }
    
    @ViewBuilder private func ErrorStateView() -> some View {
        SomethingWentWrong {
            listState = .loading
            await updateCliques(.refresh)
        }
        .padding(.horizontal, 16)
        .frame(maxHeight: .infinity)
    }
    
    @ViewBuilder private func LoadingStateView() -> some View {
        CliqueProgressView()
            .infiniteFrame()
    }
    
    private func updateCliques(_ operation: PaginationOperationType) async {
        await PaginationHelper.updateItems(
            operation,
            viewModel: viewModel,
            listState: $listState,
            paginationState: $paginationState,
            isScrollAtBottom: $isScrollAtBottom
        )
    }
}

#Preview {
    UserCliquesView(uid: User.MOCK_USERS[0].id, CliqueStore())
}
