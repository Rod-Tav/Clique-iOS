//
//  ChooseCliqueView.swift
//  Clique
//
//  Created by Rod Tavangar on 3/11/25.
//

import SwiftUI
import AdvancedList

struct ChooseCliqueView: View {
    @Environment(\.dismiss) private var dismiss
    
    @Environment(CliqueStore.self) private var cliqueStore
    
    @Environment(CreateViewModel.self) private var viewModel
    
    @State private var cliquesPgVM: UserCliquesPaginationViewModel
    
    @State private var listState: ListState = .loading
    @State private var paginationState: AdvancedListPaginationState = .idle
    @State private var isScrollAtBottom: Bool = false
    
    init(uid: String, _ cliqueStore: CliqueStore) {
        self.cliquesPgVM = .init(uid: uid, cliqueStore)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Your Cliques")
                .font(.callout.weight(.semibold))
                .foregroundStyle(Color.theme.shadesWhite95)
            
            VStack(alignment: .leading, spacing: 16) {
                AdvancedList(cliquesPgVM.items, listView: { cliques in
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
            }
            .frameTop()
        }
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder private func CliqueList(_ cliques: AdvancedList.Rows) -> some View {
        ScrollView {
            LazyVStack(spacing: 16, content: cliques)
        }
        .scrollBarIgnorePadding(16)
    }
    
    @ViewBuilder private func CliqueCell(_ clique: Clique) -> some View {
        Button {
            viewModel.newCollectionClique = clique
            dismiss()
        } label: {
            CliqueListCellView(cid: clique.id)
                .maxWidth(.leading)
                .contentShape(.rect)
        }.noHighlight()
    }
    
    @ViewBuilder private func CollectionStat(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            IconImage(icon, color: Color.theme.iconSecondary, size: 12)
            
            Text(text)
                .font(.caption2.bold())
                .textSecondary()
        }
    }
    
    private func startNewCollection() {
        dismiss()
        viewModel.selectedCollectionId = nil
        viewModel.selectedCollectionClique = nil
        viewModel.showNewCollectionSheet = true
    }
}

// MARK: Pagination state views
extension ChooseCliqueView {
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
            await updateCliques(.refresh)
        }
    }
    
    @ViewBuilder
    private func LoadingStateView() -> some View {
        CliqueProgressView()
            .infiniteFrame()
    }
    
    private func updateCliques(_ operation: PaginationOperationType) async {
        await PaginationHelper.updateItems(
            operation,
            viewModel: cliquesPgVM,
            listState: $listState,
            paginationState: $paginationState,
            isScrollAtBottom: $isScrollAtBottom
        )
    }
}
