import SwiftUI
import AdvancedList

struct UserFlicksView: View {
    @AppStorage("flicksGridColumns") private var gridColumns: Int = 3

    @Environment(TabViewCoordinator.self) private var tabViewCoordinator
    @Environment(CollectionStore.self) private var collectionStore
    @Environment(CollectionImageStore.self) private var collectionImageStore
    @Environment(UserStore.self) private var userStore
    @Environment(CliqueStore.self) private var cliqueStore

    @State private var viewModel: UserFlicksPaginationViewModel?
    @State private var listState: ListState = .loading
    @State private var paginationState: AdvancedListPaginationState = .idle
    @State private var isScrollAtBottom: Bool = false
    @State private var cachedRows: [FlickRowItem] = []
    @State private var detailCoordinator = UserFlicksDetailCoordinator()
    @State private var heroCoordinator = HeroCoordinator()
    @State private var scrollID: String?

    var body: some View {
        @Bindable var bindableTVC = tabViewCoordinator

        TabNavigationStack(path: $bindableTVC.flicksNavigationPath) {
            Group {
                if let viewModel {
                    AdvancedList(viewModel.items, listView: { _ in
                        GridLayout()
                    }, content: { flick in
                        EmptyView() // Content handled in GridLayout
                    }, listState: listState, emptyStateView: {
                        EmptyStateView()
                    }, errorStateView: { _ in
                        ErrorStateView()
                    }, loadingStateView: {
                        LoadingStateView()
                    })
                } else {
                    LoadingStateView()
                }
            }
            .primaryBackground()
            .heroOverlay {
                if let viewModel {
                    UserFlicksDetailView(
                        coordinator: detailCoordinator,
                        items: viewModel.items
                    )
                }
            }
        }
        .environment(heroCoordinator)
        .environment(detailCoordinator)
        .task {
            if viewModel == nil {
                viewModel = UserFlicksPaginationViewModel(collectionStore, collectionImageStore, userStore, cliqueStore)
            }

            if let viewModel, viewModel.items.isEmpty && listState == .loading {
                await updateFlicks(.loadFirstPage)
            }
        }
        .onChange(of: gridColumns) { _, newValue in
            // Recalculate rows when column count changes
            guard let viewModel else { return }
            cachedRows = viewModel.flatRows(from: viewModel.groupedByDate, columns: newValue)
        }
        .onChange(of: tabViewCoordinator.triggerScrollToTopOfFlicksGrid) { _, _ in
            scrollID = "TOP"
        }
    }

    // MARK: - Header Content

    private var headerContent: some View {
        HStack(spacing: 12) {
            // Flicks title with star
            HStack(alignment: .top, spacing: 0) {
                Text("Flicks")
                    .font(Font.custom("NewakeDemo", size: 28))
                    .textPrimary()

                IconImage(name: "clique-star", color: Color.theme.cliquePink, size: 8)
            }

            Spacer()

            // Trailing icons
            HStack(spacing: 8) {
                // Filter menu
                Menu {
                    ForEach([2, 3, 4], id: \.self) { count in
                        Button {
                            gridColumns = count
                        } label: {
                            HStack {
                                Text("\(count) columns")
                                if gridColumns == count {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    IconImage(name: "filter", color: Color.theme.iconPrimary, size: 26)
                }

                // Inbox
                NavigationLink(value: "NotificationsCenter") {
                    IconImage(name: "inbox", color: Color.theme.iconPrimary, size: 26)
                        .overlayTopRightNotification(when: tabViewCoordinator.hasNotification)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Grid Layout

    private func GridLayout() -> some View {
        GridSyncScrollView(coordinator: detailCoordinator, scrollToId: $scrollID) {
            LazyVStack(spacing: 0) {
                // Scroll-to-top anchor
                Color.clear
                    .frame(height: 1)
                    .id("TOP")

                // Header that scrolls with content
                headerContent
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                // Single flat list - no nested lazy containers
                ForEach(cachedRows) { row in
                    switch row {
                    case .header(let section):
                        SectionDivider(section: section)
                    case .imageRow(_, let items):
                        ImageRow(items: items)
                    }
                }

                // Pagination trigger
                if let viewModel, !viewModel.done {
                    Color.clear
                        .frame(height: 1)
                        .id(viewModel.items.count)
                        .onAppear {
                            guard paginationState == .idle else { return }
                            Task { await updateFlicks(.loadNextPage) }
                        }
                }
            }
            .scrollTargetLayout()

            if paginationState == .loading {
                CliqueProgressView()
                    .padding()
            }
        }
        .bottomTabBarPadding()
        .refreshable {
            guard paginationState == .idle else { return }
            viewModel?.refreshing = true
            await updateFlicks(.refresh)
            viewModel?.refreshing = false
        }
    }

    // MARK: - Image Row (HStack instead of LazyVGrid)

    private func ImageRow(items: [UserFlickItem]) -> some View {
        HStack(spacing: 2) {
            ForEach(items) { item in
                GridCell(item)
            }
            // Fill remaining space if row is incomplete
            if items.count < gridColumns {
                ForEach(0..<(gridColumns - items.count), id: \.self) { _ in
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                }
            }
        }
    }

    // MARK: - Section Divider

    private func SectionDivider(section: FlickDateSection) -> some View {
        HStack(spacing: 6) {
            Text(section.formattedDate)
                .font(.body.weight(.bold))
                .tracking(-0.34)
                .textPrimary()

            Text("•")
                .foregroundStyle(Color.theme.textSecondary)

            Text(section.countText)
                .font(.body)
                .tracking(-0.34)
                .foregroundStyle(Color.theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.theme.buttonTertiary)
    }

    // MARK: - Grid Cell

    private func GridCell(_ item: UserFlickItem) -> some View {
        let flick = item.flick
        return GridCollectionPreviewImage(urls: flick.imageUrl)
            .overlayCollectionPreviewStats(
                likes: flick.numLikes,
                comments: flick.numComments,
                hasLiked: flick.hasLiked,
                isLivePhoto: flick.isLivePhoto,
                isVideo: flick.isVideo,
                videoDuration: flick.videoDuration,
                videoUrl: flick.videoUrls?.videoUrl(for: .medium)
            )
            .id(flick.id)
            .heroSource(urls: flick.imageUrl) {
                tabViewCoordinator.showTabBar = false
                detailCoordinator.selectedImageId = flick.id
            }
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

        // Update cached rows after pagination completes (flat structure for scroll performance)
        cachedRows = viewModel.flatRows(from: viewModel.groupedByDate, columns: gridColumns)
    }

}
