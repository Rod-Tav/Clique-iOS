//
//  HomeFeedCollectionCell.swift
//  Clique
//
//  Created by Claude on 2025-08-29.
//

import UIKit
import SwiftUI

class HomeFeedCollectionCell: UICollectionViewCell {
    
    static let reuseIdentifier = "HomeFeedCollectionCell"
    
    private var hostingController: UIHostingController<AnyView>?
    private var feedItem: FeedItem?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupCell() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
    }
    
    func configure(
        with feedItem: FeedItem,
        collectionStore: CollectionStore,
        collectionImageStore: CollectionImageStore,
        userStore: UserStore,
        cliqueStore: CliqueStore,
        commentStore: CommentStore,
        appCoordinator: AppCoordinator,
        tabViewCoordinator: TabViewCoordinator
    ) {
        self.feedItem = feedItem
        
        // Remove existing hosting controller if any
        hostingController?.view.removeFromSuperview()
        hostingController?.removeFromParent()
        
        // Create SwiftUI view
        let feedCellView = FeedItemCellView(feedItem: feedItem)
            .environment(userStore)
            .environment(cliqueStore)
            .environment(collectionStore)
            .environment(collectionImageStore)
            .environment(commentStore)
            .environment(appCoordinator)
            .environment(tabViewCoordinator)
        
        // Wrap in AnyView for type erasure
        let hostingView = AnyView(feedCellView)
        
        // Create hosting controller
        let controller = UIHostingController(rootView: hostingView)
        controller.view.backgroundColor = .clear
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        
        // Add to cell
        contentView.addSubview(controller.view)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            controller.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            controller.view.topAnchor.constraint(equalTo: contentView.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        
        hostingController = controller
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        // Clean up hosting controller
        hostingController?.view.removeFromSuperview()
        hostingController?.removeFromParent()
        hostingController = nil
        feedItem = nil
    }
    
    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        // Calculate the actual height needed for the content
        let targetSize = CGSize(width: layoutAttributes.frame.width, height: UIView.layoutFittingCompressedSize.height)
        
        // Use the hosting controller's view to calculate size
        if let hostingView = hostingController?.view {
            let size = hostingView.systemLayoutSizeFitting(targetSize,
                                                           withHorizontalFittingPriority: .required,
                                                           verticalFittingPriority: .fittingSizeLevel)
            
            var newFrame = layoutAttributes.frame
            newFrame.size.height = size.height
            layoutAttributes.frame = newFrame
        }
        
        return layoutAttributes
    }
}