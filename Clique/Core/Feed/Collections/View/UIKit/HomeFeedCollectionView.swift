//
//  HomeFeedCollectionView.swift
//  Clique
//
//  Created by Claude on 2025-08-29.
//

import SwiftUI
import UIKit

struct HomeFeedCollectionView: UIViewControllerRepresentable {
    
    @Environment(UserStore.self) private var userStore
    @Environment(CliqueStore.self) private var cliqueStore
    @Environment(CollectionStore.self) private var collectionStore
    @Environment(CollectionImageStore.self) private var collectionImageStore
    @Environment(CommentStore.self) private var commentStore
    @Environment(AppCoordinator.self) private var appCoordinator
    @Environment(TabViewCoordinator.self) private var tabViewCoordinator
    
    @AppStorage("feedLayoutStyle") private var feedLayoutStyle: String = "single"
    
    let viewModel: HomeFeedPaginationViewModel
    @Binding var scrollToTop: Bool
    
    func makeUIViewController(context: Context) -> HomeFeedCollectionViewController {
        let viewController = HomeFeedCollectionViewController(
            viewModel: viewModel,
            collectionStore: collectionStore,
            collectionImageStore: collectionImageStore,
            userStore: userStore,
            cliqueStore: cliqueStore,
            commentStore: commentStore,
            appCoordinator: appCoordinator,
            tabViewCoordinator: tabViewCoordinator
        )
        
        viewController.layoutStyle = HomeFeedCompositionalLayout.LayoutStyle(from: feedLayoutStyle)
        context.coordinator.viewController = viewController
        
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: HomeFeedCollectionViewController, context: Context) {
        // Update layout style if changed
        uiViewController.layoutStyle = HomeFeedCompositionalLayout.LayoutStyle(from: feedLayoutStyle)
        
        // Handle scroll to top
        if scrollToTop {
            uiViewController.scrollToTop(animated: true)
            DispatchQueue.main.async {
                scrollToTop = false
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        weak var viewController: HomeFeedCollectionViewController?
    }
}