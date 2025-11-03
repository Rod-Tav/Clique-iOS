//
//  CliqueMembersListSheetView.swift
//  Clique
//
//  Created by Rod Tavangar on 12/12/24.
//

import SwiftUI
import AdvancedList

struct CliqueMembersListSheetView: View {
    @Environment(\.dismiss) private var dismiss
    
    @Environment(UserStore.self) private var userStore
    @Environment(CliqueStore.self) private var cliqueStore
    
    @Environment(TabViewCoordinator.self) private var tabViewCoordinator
    
    @State var viewModel: CliqueMembersPaginationViewModel
    @State private var followUserViewModel = FollowUserViewModel()
    
    @State private var listState: ListState = .loading
    @State private var paginationState: AdvancedListPaginationState = .idle
    @State private var isScrollAtBottom: Bool = false
    
    let cid: String
    let fromFeed: Bool
    
    private var clique: Clique? {
        cliqueStore.cliques[cid]
    }
    
    init(cid: String, fromFeed: Bool = false, _ userStore: UserStore, _ cliqueStore: CliqueStore) {
        self.cid = cid
        self.fromFeed = fromFeed
        self.viewModel = .init(cid: cid, userStore, cliqueStore)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            TopBar()
            
            AdvancedList(viewModel.items, listView: { users in
                MemberList(users)
            }, content: { userID in
                if let user = userStore.users[userID] {
                    MemberCell(user)
                }
            }, listState: listState, emptyStateView: {
                EmptyStateView()
            }, errorStateView: { _ in
                ErrorStateView()
            }, loadingStateView: {
                LoadingStateView()
            })
            .pagination(.init(type: .lastItem, shouldLoadNextPage: { Task { await updateMembers(.loadNextPage) } }) { })
            .task {
                guard listState == .loading else { return }
                await updateMembers(.loadFirstPage)
            }
//            .environment(followUserViewModel)
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Top Bar
    @ViewBuilder private func TopBar() -> some View {
        TopAppBar(
            type: .small,
            leadingIcon: {},
            header: {
                if fromFeed, let clique {
                    Button {
                        dismiss()
                        tabViewCoordinator.navigate(to: clique)
                    } label: {
                        CliquePill(cid: cid, type: .feedCell)
                    }.buttonStyle(.noHighlight)
                } else {
                    Text("Members")
                        .textPrimary()
                        .font(.callout.bold())
                }
            },
            trailingIcon: {}
        )
    }
    
    // MARK: - Member list
    @ViewBuilder private func MemberList(_ users: AdvancedList.Rows) -> some View {
        ScrollView {
            LazyVStack(spacing: 16, content: users)
        }
        .scrollBarIgnorePadding(16)
    }
    
    // MARK: - Member cell
    @ViewBuilder private func MemberCell(_ user: User) -> some View {
        Button {
            dismiss()
            tabViewCoordinator.navigate(to: user)
        } label: {
            UserCellWithFollow(uid: user.id, isLeader: user.id == viewModel.items.first?.id)
        }
    }
}

// MARK: - Pagination state views
extension CliqueMembersListSheetView {
    // this should never happen
    @ViewBuilder private func EmptyStateView() -> some View {
        NothingHereYetView()
    }
    
    @ViewBuilder private func ErrorStateView() -> some View {
        SomethingWentWrong {
            listState = .loading
            await updateMembers(.refresh)
        }
        .padding(.horizontal, 16)
        .maxHeight()
    }
    
    @ViewBuilder private func LoadingStateView() -> some View {
        CliqueProgressView()
            .infiniteFrame()
    }
    
    private func updateMembers(_ operation: PaginationOperationType) async {
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
    CliqueMembersListSheetView(cid: Clique.MOCK_CLIQUES[4].id, UserStore(), CliqueStore())
        .environment(TabViewCoordinator())
}
