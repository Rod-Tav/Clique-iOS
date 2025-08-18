//
//  PhotoGridCell.swift
//  Clique
//
//  Created by Rod Tavangar on 8/15/25.
//

import SwiftUI
import Photos

/// Individual photo cell in the grid with selection state visualization.
struct PhotoGridCell: View {
    /// The photo asset to display
    let asset: PHAsset
    /// Whether this photo is currently selected
    let isSelected: Bool
    /// Cached thumbnail image if available
    let thumbnail: UIImage?
    /// Whether this photo is being removed during drag selection
    var isBeingRemoved: Bool = false
    /// Tap action callback
    let action: () -> Void
    
    /// Calculated cell size for 3-column grid
    private var cellSize: CGFloat {
        (UIScreen.width - 4) / 3
    }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(cellSize)
                        .clipped()
                } else {
                    loadingView
                }
                
                if isSelected && !isBeingRemoved {
                    selectionOverlay
                } else if isBeingRemoved {
                    removalOverlay
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
    
    /// Loading placeholder while thumbnail loads
    private var loadingView: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .frame(cellSize)
            .overlay(
                ProgressView()
                    .scaleEffect(0.5)
            )
    }
    
    
    /// Blue checkmark overlay for selected photos
    private var selectionOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
            
            VStack {
                HStack {
                    Spacer()
                    
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: "checkmark")
                            .foregroundColor(.white)
                            .font(.system(size: 14, weight: .bold))
                    }
                    .padding(4)
                }
                
                Spacer()
            }
        }
        .animation(.snappy(duration: 0.25, extraBounce: 0), value: isSelected)
    }
    
    /// Red minus overlay for photos being removed during drag
    private var removalOverlay: some View {
        ZStack {
            Color.red.opacity(0.4)
            
            VStack {
                HStack {
                    Spacer()
                    
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: "minus")
                            .foregroundColor(.white)
                            .font(.system(size: 14, weight: .bold))
                    }
                    .padding(4)
                }
                
                Spacer()
            }
        }
        .animation(.snappy(duration: 0.25, extraBounce: 0), value: isBeingRemoved)
    }
}
