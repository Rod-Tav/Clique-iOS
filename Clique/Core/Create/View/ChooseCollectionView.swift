//
//  ChooseCollectionView.swift
//  Clique
//
//  Created by Rod Tavangar on 3/11/25.
//

import SwiftUI
import AdvancedList
import Toasts

struct ChooseCollectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentToast) private var presentToast

    @Environment(UserStore.self) private var userStore
    @Environment(CliqueStore.self) private var cliqueStore
    @Environment(CollectionStore.self) private var collectionStore
    @Environment(CollectionImageStore.self) private var collectionImageStore

    @Environment(AppCoordinator.self) private var appCoordinator
    @Environment(TabViewCoordinator.self) private var tabViewCoordinator

    @Environment(CreateViewModel.self) private var viewModel
    
    @State private var collectionsPgVM: UserCollectionsPaginationViewModel
    
    @State private var listState: ListState = .loading
    @State private var paginationState: AdvancedListPaginationState = .idle
    @State private var isScrollAtBottom: Bool = false

    init(uid: String, _ collectionStore: CollectionStore, _ collectionImageStore: CollectionImageStore) {
        self.collectionsPgVM = .init(uid: uid, collectionStore, collectionImageStore)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Your Collections")
                .font(.callout.weight(.semibold))
                .foregroundStyle(Color.theme.textPrimary)
            
            VStack(spacing: 16) {
                CliqueButton(
                    type: .primary,
                    leadingIcon: "plus",
                    text: "New collection",
                    fullWidth: true
                ) {
                    startNewCollection()
                }
                
                AdvancedList(collectionsPgVM.items, listView: { collections in
                    CollectionList(collections)
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
                .onAppear {
                    Task {
                        guard listState == .loading else { return }
                        await updateCollections(.loadFirstPage)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder private func CollectionList(_ collections: AdvancedList.Rows) -> some View {
        ScrollView {
            LazyVStack(spacing: 16, content: collections)
        }
        .scrollBarIgnorePadding(16)
    }
    
    @ViewBuilder private func CollectionCell(_ collection: ClCollection) -> some View {
        Button {
            viewModel.selectedCollectionId = collection.id
            viewModel.collectionToGoTo = collection
            if let clique = cliqueStore.cliques[collection.cliqueId] {
                viewModel.selectedCollectionClique = clique
                dismiss()
            } else {
                print("geting clique")
                Task {
                    do {
                        viewModel.selectedCollectionClique = try await CliqueService.getCliqueById(id: collection.cliqueId)
                        dismiss()
                    } catch {
                        presentToast(Toasts.somethingWentWrong)
                    }
                }
            }
        } label: {
            HStack(spacing: 16) {
                // TODO: DRY
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.theme.strokeSecondary, lineWidth: 0.5)
                        .frame(64)
                        .scaleEffect(0.77, anchor: .top)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.theme.surfacesBackgroundPrimary)
                        .stroke(Color.theme.strokeSecondary, lineWidth: 0.5)
                        .frame(64)
                        .scaleEffect(0.90, anchor: .top)
                        .offset(y: 3.38 / 2)
                    
                    Group {
                        if let coverPhoto = collection.coverPhoto {
                            ProfileCollectionCoverPhotoAsyncImage(urls: coverPhoto, side: 64, quality: .medium)
                        } else if let mostLikedImage = collection.mostLikedImage, let urls = collectionImageStore.images[mostLikedImage]?.imageUrl {
                            ProfileCollectionCoverPhotoAsyncImage(urls: urls, side: 64, quality: .medium)
                        } else {
                            ProfileCollectionPlaceholder(side: 64)
                        }
                    }
                    .fetchMostLikedImage(collectionId: collection.id)
                    .offset(y: 3.38)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    CliquePill(cid: collection.cliqueId, type: .createCollections)
                    
                    Text(collection.name)
                        .font(.footnote.bold())
                        .foregroundStyle(Color.theme.textPrimary)

                    HStack(spacing: 8) {
                        CollectionStat(icon: "calendar", text: formatDateMdyy(collection.creation))

                        CollectionStat(icon: "images-posts", text: String(collection.displayFlickCount(currentUserId: userStore.currentUserId)))
                    }
                }
            }
            .maxWidth(.leading)
            .contentShape(.rect)
        }
        .noHighlight()
    }
    
    @ViewBuilder private func CollectionStat(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            IconImage(name: icon, color: Color.theme.iconSecondary, size: 12)
            
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
        viewModel.showNewCollectionSheet = true
    }
}

// MARK: Pagination state views
extension ChooseCollectionView {
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
    }
    
    @ViewBuilder
    private func LoadingStateView() -> some View {
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
