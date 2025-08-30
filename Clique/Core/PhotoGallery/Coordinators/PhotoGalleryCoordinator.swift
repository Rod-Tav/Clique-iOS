//
//  PhotoGalleryCoordinator.swift
//  Clique
//
//  Created by Assistant on 12/29/24.
//

import SwiftUI

@Observable
final class PhotoGalleryCoordinator {
    // MARK: - Grid State
    var gridScale: CGFloat = 1.0
    var columnCount: Int = 3
    var lastScale: CGFloat = 1.0
    
    // MARK: - Detail View State
    var selectedPhotoId: String?
    var showDetailView: Bool = false
    var detailScrollPosition: String?
    
    // MARK: - Navigation
    var navigationPath = NavigationPath()
    
    // Grid scale boundaries
    let minScale: CGFloat = 0.5  // 5 columns
    let maxScale: CGFloat = 2.0  // 1 column
    
    init() {
        updateColumnCount()
    }
    
    func updateScale(_ scale: CGFloat) {
        gridScale = min(max(scale, minScale), maxScale)
        updateColumnCount()
    }
    
    func updateColumnCount() {
        // Map scale to column count
        // Scale 0.5 = 5 columns
        // Scale 1.0 = 3 columns  
        // Scale 2.0 = 1 column
        if gridScale <= 0.6 {
            columnCount = 5
        } else if gridScale <= 0.8 {
            columnCount = 4
        } else if gridScale <= 1.2 {
            columnCount = 3
        } else if gridScale <= 1.6 {
            columnCount = 2
        } else {
            columnCount = 1
        }
    }
    
    func selectPhoto(_ id: String) {
        selectedPhotoId = id
        showDetailView = true
    }
    
    func dismissDetail() {
        showDetailView = false
        selectedPhotoId = nil
    }
    
    func setColumnCount(_ count: Int) {
        withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8)) {
            columnCount = count
            // Update scale to match the column count
            switch count {
            case 1: gridScale = 2.0
            case 2: gridScale = 1.4
            case 3: gridScale = 1.0
            case 4: gridScale = 0.7
            case 5: gridScale = 0.5
            default: gridScale = 1.0
            }
        }
    }
}