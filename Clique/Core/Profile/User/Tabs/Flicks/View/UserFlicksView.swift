import SwiftUI
import AdvancedList

struct UserFlicksView: View {
    @Environment(CollectionStore.self) var collectionStore
    @Environment(CollectionImageStore.self) var collectionImageStore
    @Environment(UserStore.self) var userStore

    @State private var viewModel: UserFlicksPaginationViewModel?
    @State private var listState: ListState = .loading
    @State private var paginationState: AdvancedListPaginationState = .idle
    @State private var isScrollAtBottom: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            flicksGrid
        }
        .primaryBackground()
        .navigationTitle("My Flicks")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if viewModel == nil {
                viewModel = UserFlicksPaginationViewModel(
                    collectionStore,
                    collectionImageStore,
                    userStore
                )
                Task { await updateItems(.loadFirstPage) }
            }
        }
    }

    private var flicksGrid: some View {
        AdvancedList(viewModel?.items ?? [], listView: { rows in
            FlicksGridList(rows)
        }, content: { image in
            GridCollectionPreviewImage(urls: image.imageUrl)
                .overlayCollectionPreviewStats(
                    likes: image.numLikes,
                    comments: image.numComments,
                    hasLiked: image.hasLiked,
                    isLivePhoto: image.mediaType == .LIVE,
                    isVideo: image.mediaType == .VIDEO,
                    videoDuration: nil,
                    videoUrl: image.videoUrls?.videoUrl(for: .medium),
                    compact: false
                )
                .contentShape(.rect)
        }, listState: listState, emptyStateView: {
            NothingHereYetView()
        }, errorStateView: { _ in
            Text("Something went wrong")
                .textPrimary()
        }, loadingStateView: {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        })
        .pagination(.init(type: .lastItem, shouldLoadNextPage: { Task { await updateItems(.loadNextPage) } }) { })
    }

    private func FlicksGridList(_ rows: AdvancedList.Rows) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: 2),
            GridItem(.flexible(), spacing: 2),
            GridItem(.flexible(), spacing: 2)
        ]

        return ScrollView {
            LazyVGrid(columns: columns, spacing: 2, content: rows)
        }
        .refreshable {
            await updateItems(.refresh)
        }
    }

    private func updateItems(_ operation: PaginationOperationType) async {
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
