import SwiftUI

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
            if listState == .loading && (viewModel?.items.isEmpty ?? true) {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if listState == .error {
                ErrorView {
                    Task { await updateItems(.refresh) }
                }
            } else if viewModel?.items.isEmpty ?? true {
                NothingHereYetView()
            } else {
                flicksGrid
            }
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
                Task { await updateItems(.refresh) }
            }
        }
    }

    private var flicksGrid: some View {
        AdvancedList(
            viewModel?.items ?? [],
            refreshAction: { await updateItems(.refresh) },
            paginationState: $paginationState,
            listState: $listState,
            isScrollAtBottom: $isScrollAtBottom
        ) { image in
            FlickGridCell(image: image)
                .aspectRatio(1, contentMode: .fill)
        }
        .scrollIndicators(.hidden)
        .pagination(.init(
            type: .lastItem,
            shouldLoadNextPage: {
                Task { await updateItems(.loadNextPage) }
            }
        ))
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
