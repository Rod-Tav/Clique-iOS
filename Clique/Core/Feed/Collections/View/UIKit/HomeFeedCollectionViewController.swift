//
//  HomeFeedCollectionViewController.swift
//  Clique
//
//  Created by Claude on 2025-08-29.
//

import UIKit
import SwiftUI
import Combine

class HomeFeedCollectionViewController: UIViewController {
    
    // MARK: - Properties
    
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, FeedItem>!
    private var viewModel: HomeFeedPaginationViewModel
    private var cancellables = Set<AnyCancellable>()
    
    private let collectionStore: CollectionStore
    private let collectionImageStore: CollectionImageStore
    private let userStore: UserStore
    private let cliqueStore: CliqueStore
    private let commentStore: CommentStore
    private let appCoordinator: AppCoordinator
    private let tabViewCoordinator: TabViewCoordinator
    
    private var isLoadingMore = false
    private var refreshControl: UIRefreshControl!
    
    var layoutStyle: HomeFeedCompositionalLayout.LayoutStyle = .singleColumn {
        didSet {
            // Only update layout if collectionView has been initialized
            if collectionView != nil {
                updateLayout()
            }
        }
    }
    
    enum Section: Hashable {
        case main
    }
    
    // MARK: - Initialization
    
    init(
        viewModel: HomeFeedPaginationViewModel,
        collectionStore: CollectionStore,
        collectionImageStore: CollectionImageStore,
        userStore: UserStore,
        cliqueStore: CliqueStore,
        commentStore: CommentStore,
        appCoordinator: AppCoordinator,
        tabViewCoordinator: TabViewCoordinator
    ) {
        self.viewModel = viewModel
        self.collectionStore = collectionStore
        self.collectionImageStore = collectionImageStore
        self.userStore = userStore
        self.cliqueStore = cliqueStore
        self.commentStore = commentStore
        self.appCoordinator = appCoordinator
        self.tabViewCoordinator = tabViewCoordinator
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupCollectionView()
        setupDataSource()
        setupRefreshControl()
        bindViewModel()
        
        Task {
            await loadInitialData()
        }
    }
    
    // MARK: - Setup
    
    private func setupCollectionView() {
        let layout = HomeFeedCompositionalLayout.createLayout(style: layoutStyle)
        
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = UIColor(Color.theme.surfacesBackgroundPrimary)
        collectionView.delegate = self
        collectionView.prefetchDataSource = self
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        
        // Register cell
        collectionView.register(HomeFeedCollectionCell.self, forCellWithReuseIdentifier: HomeFeedCollectionCell.reuseIdentifier)
        
        view.addSubview(collectionView)
    }
    
    private func updateLayout() {
        let newLayout = HomeFeedCompositionalLayout.createLayout(style: layoutStyle)
        collectionView.setCollectionViewLayout(newLayout, animated: true)
    }
    
    private func setupDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Section, FeedItem>(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, feedItem in
            guard let self = self else { return nil }
            
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: HomeFeedCollectionCell.reuseIdentifier,
                for: indexPath
            ) as? HomeFeedCollectionCell
            
            cell?.configure(
                with: feedItem,
                collectionStore: self.collectionStore,
                collectionImageStore: self.collectionImageStore,
                userStore: self.userStore,
                cliqueStore: self.cliqueStore,
                commentStore: self.commentStore,
                appCoordinator: self.appCoordinator,
                tabViewCoordinator: self.tabViewCoordinator
            )
            
            return cell
        }
    }
    
    private func setupRefreshControl() {
        refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        collectionView.refreshControl = refreshControl
    }
    
    // MARK: - Data Loading
    
    private func bindViewModel() {
        // Observe view model changes
        viewModel.itemsDidChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateSnapshot()
            }
            .store(in: &cancellables)
    }
    
    @MainActor
    private func loadInitialData() async {
        guard viewModel.items.isEmpty else {
            updateSnapshot()
            return
        }
        
        do {
            viewModel.page = 0
            viewModel.done = false
            let items = try await viewModel.fetchFunction(viewModel.makeInput(page: 0, size: viewModel.size))
            viewModel.items = items
            viewModel.done = items.count < viewModel.size
            viewModel.page = 1
            
            updateSnapshot()
        } catch {
            print("Error loading initial data: \(error)")
        }
    }
    
    @MainActor
    private func loadMoreData() async {
        guard !isLoadingMore, !viewModel.done else { return }
        
        isLoadingMore = true
        
        do {
            let newItems = try await viewModel.fetchFunction(viewModel.makeInput(page: viewModel.page, size: viewModel.size))
            
            if !newItems.isEmpty {
                viewModel.items.append(contentsOf: newItems)
                viewModel.page += 1
                viewModel.done = newItems.count < viewModel.size
                
                updateSnapshot(animated: false)
            }
        } catch {
            print("Error loading more data: \(error)")
        }
        
        isLoadingMore = false
    }
    
    @objc private func handleRefresh() {
        Task {
            viewModel.refreshing = true
            
            // Clear cache
            await CacheControl.shared.refreshHomeFeed()
            
            // Trigger refresh
            viewModel.page = 0
            viewModel.done = false
            
            do {
                let items = try await viewModel.fetchFunction(viewModel.makeInput(page: 0, size: viewModel.size))
                viewModel.items = items
                viewModel.done = items.count < viewModel.size
                viewModel.page = 1
                
                await MainActor.run {
                    updateSnapshot()
                    refreshControl.endRefreshing()
                }
            } catch {
                await MainActor.run {
                    refreshControl.endRefreshing()
                }
            }
            
            viewModel.refreshing = false
        }
    }
    
    private func updateSnapshot(animated: Bool = true) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, FeedItem>()
        snapshot.appendSections([.main])
        snapshot.appendItems(viewModel.items, toSection: .main)
        
        dataSource.apply(snapshot, animatingDifferences: animated)
    }
    
    // MARK: - Public Methods
    
    func scrollToTop(animated: Bool = true) {
        guard collectionView != nil else { return }
        collectionView.setContentOffset(.zero, animated: animated)
    }
}

// MARK: - UICollectionViewDelegate

extension HomeFeedCollectionViewController: UICollectionViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let frameHeight = scrollView.frame.size.height
        
        // Load more when nearing bottom
        if offsetY > contentHeight - frameHeight * 2 {
            Task {
                await loadMoreData()
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Handle cell selection if needed
        guard let feedItem = dataSource.itemIdentifier(for: indexPath) else { return }
        
        if let collection = feedItem.collection {
            // Navigate to collection detail
            tabViewCoordinator.navigate(to: collection)
        }
    }
}

// MARK: - UICollectionViewDataSourcePrefetching

extension HomeFeedCollectionViewController: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        // Prefetch images for upcoming cells
        for indexPath in indexPaths {
            if let feedItem = dataSource.itemIdentifier(for: indexPath),
               let collection = feedItem.collection {
                // Get images from collection store
                if let storedCollection = collectionStore.collections[collection.id] {
                    let images = storedCollection.images
                    // Prefetch medium quality for feed view
                    CollectionImagePrefetcher.instance.prefetchMediumQuality(
                        collectionId: collection.id,
                        images: images
                    )
                }
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        // Cancel prefetching for cells that are no longer needed
        for indexPath in indexPaths {
            if let feedItem = dataSource.itemIdentifier(for: indexPath),
               let collectionId = feedItem.collection?.id {
                CollectionImagePrefetcher.instance.stopMediumPrefetching(collectionId: collectionId)
            }
        }
    }
}
