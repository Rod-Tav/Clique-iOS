//
//  HomeFeedCompositionalLayout.swift
//  Clique
//
//  Created by Claude on 2025-08-29.
//

import UIKit

enum HomeFeedCompositionalLayout {
    
    enum LayoutStyle {
        case singleColumn
        case twoColumn
        case threeColumn
        
        var columnCount: Int {
            switch self {
            case .singleColumn: return 1
            case .twoColumn: return 2
            case .threeColumn: return 3
            }
        }
    }
    
    static func createLayout(style: LayoutStyle = .singleColumn) -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, layoutEnvironment in
            
            switch style {
            case .singleColumn:
                return createSingleColumnSection()
            case .twoColumn:
                return createMultiColumnSection(columns: 2)
            case .threeColumn:
                return createMultiColumnSection(columns: 3)
            }
        }
        
        // Configure layout for smooth scrolling
        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.interSectionSpacing = 16
        layout.configuration = config
        
        return layout
    }
    
    private static func createSingleColumnSection() -> NSCollectionLayoutSection {
        // Item - full width
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(400) // Dynamic height based on content
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        // Group - vertical stack
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(400)
        )
        let group = NSCollectionLayoutGroup.vertical(
            layoutSize: groupSize,
            subitems: [item]
        )
        
        // Section
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 16
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 16, trailing: 0)
        
        return section
    }
    
    private static func createMultiColumnSection(columns: Int) -> NSCollectionLayoutSection {
        // Item
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0 / CGFloat(columns)),
            heightDimension: .estimated(300) // Smaller height for grid items
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)
        
        // Group - horizontal
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(300)
        )
        
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            subitem: item,
            count: columns
        )
        
        // Section
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 8
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 16, trailing: 8)
        
        return section
    }
    
    // MARK: - Adaptive Layout
    
    static func createAdaptiveLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, layoutEnvironment in
            let containerWidth = layoutEnvironment.container.effectiveContentSize.width
            
            // Determine number of columns based on width
            let columns: Int
            if containerWidth < 500 {
                columns = 1 // iPhone portrait
            } else if containerWidth < 900 {
                columns = 2 // iPhone landscape or iPad portrait
            } else {
                columns = 3 // iPad landscape
            }
            
            if columns == 1 {
                return createSingleColumnSection()
            } else {
                return createMultiColumnSection(columns: columns)
            }
        }
        
        return layout
    }
    
    // MARK: - Waterfall Layout
    
    static func createWaterfallLayout() -> UICollectionViewLayout {
        // This would require a custom UICollectionViewLayout subclass
        // for Pinterest-style waterfall layout with variable heights
        // For now, using the adaptive layout as a fallback
        return createAdaptiveLayout()
    }
}