import SwiftUI
import AdvancedList

struct UserFlicksView: View {
    @AppStorage("flicksGridColumns") private var gridColumns: Int = 3

    @Environment(TabViewCoordinator.self) private var tabViewCoordinator
    @Environment(CollectionStore.self) private var collectionStore
    @Environment(CollectionImageStore.self) private var collectionImageStore
    @Environment(UserStore.self) private var userStore

    @State private var viewModel: UserFlicksPaginationViewModel?
    @State private var listState: ListState = .loading
    @State private var paginationState: AdvancedListPaginationState = .idle
    @State private var isScrollAtBottom: Bool = false

    var body: some View {
        @Bindable var bindableTVC = tabViewCoordinator

        TabNavigationStack(path: $bindableTVC.flicksNavigationPath) {
            VStack(spacing: 0) {
                topBar

                if let viewModel {
                    AdvancedList(viewModel.items, listView: { items in
                        GridLayout(items)
                    }, content: { flick in
                        GridCell(flick)
                    }, listState: listState, emptyStateView: {
                        EmptyStateView()
                    }, errorStateView: { _ in
                        ErrorStateView()
                    }, loadingStateView: {
                        LoadingStateView()
                    })
                    .pagination(.init(type: .lastItem, shouldLoadNextPage: {
                        Task { await updateFlicks(.loadNextPage) }
                    }) { })
                } else {
                    LoadingStateView()
                }
            }
            .primaryBackground()
        }
        .task {
            if viewModel == nil {
                viewModel = UserFlicksPaginationViewModel(collectionStore, collectionImageStore, userStore)
            }

            if let viewModel, viewModel.items.isEmpty && listState == .loading {
                await updateFlicks(.loadFirstPage)
            }
        }
    }

    // MARK: - Subviews

    private var topBar: some View {
        HStack {
            Text("My Flicks")
                .font(.title2.weight(.bold))
                .textPrimary()

            Spacer()

            Text("\(viewModel?.items.count ?? 0) flicks")
                .font(.subheadline)
                .foregroundStyle(Color.theme.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func GridLayout(_ items: AdvancedList.Rows) -> some View {
        ScrollView {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: gridColumns),
                spacing: 2,
                content: items
            )
            .scrollTargetLayout()

            if paginationState == .loading {
                CliqueProgressView()
                    .padding()
            }
        }
        .refreshable {
            guard paginationState == .idle else { return }
            viewModel?.refreshing = true
            await updateFlicks(.refresh)
            viewModel?.refreshing = false
        }
    }

    private func GridCell(_ flick: CollectionImage) -> some View {
        GridCollectionPreviewImage(urls: flick.imageUrl)
            .overlay(alignment: .bottomLeading) {
                if flick.numLikes > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                        Text("\(flick.numLikes)")
                            .font(.caption2)
                    }
                    .foregroundStyle(.white)
                    .padding(4)
                    .background(.black.opacity(0.5))
                    .roundCorners(4)
                    .padding(4)
                }
            }
            .id(flick.id)
    }

    // MARK: - State Views

    private func EmptyStateView() -> some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(Color.theme.textSecondary)

            Text("No flicks yet")
                .font(.headline)
                .textPrimary()

            Text("Your uploaded flicks will appear here")
                .font(.subheadline)
                .foregroundStyle(Color.theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func ErrorStateView() -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(Color.theme.textSecondary)

            Text("Failed to load flicks")
                .font(.headline)
                .textPrimary()

            Text("Something went wrong. Please try again.")
                .font(.subheadline)
                .foregroundStyle(Color.theme.textSecondary)
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task {
                    listState = .loading
                    await updateFlicks(.loadFirstPage)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func LoadingStateView() -> some View {
        VStack {
            CliqueProgressView()
            Text("Loading your flicks...")
                .font(.subheadline)
                .foregroundStyle(Color.theme.textSecondary)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helper Functions

    private func updateFlicks(_ operation: PaginationOperationType) async {
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
