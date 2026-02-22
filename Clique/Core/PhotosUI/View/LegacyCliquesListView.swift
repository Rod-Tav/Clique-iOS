//
//  LegacyCliquesListView.swift
//  Clique
//
//  Standalone cliques list for the Legacy tab.
//

import SwiftUI
import AdvancedList

@available(iOS 26, *)
struct LegacyCliquesListView: View {
    @Environment(UserStore.self) var userStore
    @Environment(CliqueStore.self) var cliqueStore

    @State var viewModel: UserCliquesPaginationViewModel?

    @State var listState: ListState = .loading
    @State var paginationState: AdvancedListPaginationState = .idle
    @State var isScrollAtBottom: Bool = false

    var body: some View {
        Group {
            if let viewModel {
                AdvancedList(viewModel.items, listView: { cliques in
                    CliqueList(cliques)
                }, content: { cliqueID in
                    if let clique = cliqueStore.cliques[cliqueID] {
                        CliqueCell(clique)
                    }
                }, listState: listState, emptyStateView: {
                    NothingHereYetView()
                }, errorStateView: { _ in
                    SomethingWentWrong {
                        listState = .loading
                        await updateCliques(.refresh)
                    }
                    .padding(.horizontal, 16)
                    .frame(maxHeight: .infinity)
                }, loadingStateView: {
                    CliqueProgressView()
                        .infiniteFrame()
                })
                .pagination(.init(type: .lastItem, shouldLoadNextPage: { Task { await updateCliques(.loadNextPage) } }) { })
            } else {
                CliqueProgressView()
                    .infiniteFrame()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("My Cliques")
                    .font(.headline)
            }
        }
        .navigationDestination(for: Clique.self) { clique in
            CliqueProfileView(cid: clique.id)
                .navigationBarBackButtonHidden()
        }
        .onAppear {
            guard viewModel == nil, let uid = userStore.currentUserId else { return }
            viewModel = UserCliquesPaginationViewModel(uid: uid, cliqueStore)
            Task { await updateCliques(.loadFirstPage) }
        }
    }

    @ViewBuilder
    private func CliqueList(_ cliques: AdvancedList.Rows) -> some View {
        ScrollView {
            LazyVStack(spacing: 16, content: cliques)
                .padding(16)
        }
    }

    @ViewBuilder
    private func CliqueCell(_ clique: Clique) -> some View {
        NavigationLink(value: clique) {
            CliqueListCellView(cid: clique.id)
        }
        .buttonStyle(.noHighlight)
    }

    private func updateCliques(_ operation: PaginationOperationType) async {
        guard let viewModel else { return }
        await PaginationHelper.updateItems(
            operation,
            viewModel: viewModel,
            listState: $listState,
            paginationState: $paginationState,
            isScrollAtBottom: $isScrollAtBottom
        )
    }
}
