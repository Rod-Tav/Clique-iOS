//
//  PhotoGalleryView.swift
//  Clique
//
//  Created by Assistant on 12/29/24.
//

import SwiftUI

struct PhotoGalleryView: View {
    @Environment(\.safeAreaInsets) private var safeAreaInsets
    @State private var coordinator = PhotoGalleryCoordinator()
    @State private var currentScale: CGFloat = 1.0
    @State private var previousScale: CGFloat = 1.0
    
    // Mock data - using IDs for now
    let photoIds = Array(1...100).map { "photo_\($0)" }
    
    // Grid configuration
    var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 2), count: coordinator.columnCount)
    }
    
    var body: some View {
        NavigationStack(path: $coordinator.navigationPath) {
            ZStack {
                Color.theme.surfacesBackgroundPrimary
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    topBar
                    
                    ScrollView {
                        photoGrid
                            .padding(.horizontal, 2)
                            .padding(.top, 2)
                    }
                    .gesture(pinchGesture)
                }
            }
            .navigationDestination(for: String.self) { photoId in
                PhotoDetailView(photoId: photoId)
                    .environment(coordinator)
            }
        }
        .environment(coordinator)
    }
    
    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let delta = value / previousScale
                previousScale = value
                
                // Apply the scale change
                let newScale = coordinator.gridScale * delta
                coordinator.updateScale(newScale)
            }
            .onEnded { _ in
                previousScale = 1.0
                coordinator.lastScale = coordinator.gridScale
                
                // Snap to nearest column count for better UX
                withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8)) {
                    snapToNearestColumnCount()
                }
            }
    }
    
    private func snapToNearestColumnCount() {
        // Snap to predefined scale values for clean column counts
        let targetScale: CGFloat
        switch coordinator.columnCount {
        case 5: targetScale = 0.5
        case 4: targetScale = 0.7
        case 3: targetScale = 1.0
        case 2: targetScale = 1.4
        case 1: targetScale = 2.0
        default: targetScale = 1.0
        }
        coordinator.updateScale(targetScale)
    }
    
    private var topBar: some View {
        HStack {
            Text("Photos")
                .font(.largeTitle.bold())
                .foregroundStyle(Color.theme.textPrimary)
            
            Spacer()
            
            Menu {
                ForEach(1...5, id: \.self) { columns in
                    Button {
                        coordinator.setColumnCount(columns)
                    } label: {
                        HStack {
                            Label {
                                Text("\(columns) Column\(columns == 1 ? "" : "s")")
                            } icon: {
                                Image(systemName: gridIconName(for: columns))
                            }
                            
                            if coordinator.columnCount == columns {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: gridIconName(for: coordinator.columnCount))
                        .font(.callout)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .foregroundStyle(Color.theme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.theme.textSecondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.theme.surfacesBackgroundPrimary)
    }
    
    private func gridIconName(for columns: Int) -> String {
        switch columns {
        case 1: return "square.fill"
        case 2: return "square.grid.2x2.fill"
        case 3: return "square.grid.3x3.fill"
        case 4, 5: return "square.grid.4x3.fill"
        default: return "square.grid.3x3.fill"
        }
    }
    
    private var photoGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 2) {
            ForEach(photoIds, id: \.self) { photoId in
                PhotoGalleryCell(photoId: photoId)
                    .onTapGesture {
                        coordinator.selectPhoto(photoId)
                        coordinator.navigationPath.append(photoId)
                    }
            }
        }
        .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.8), value: coordinator.columnCount)
    }
}

// MARK: - Grid Cell
struct PhotoGalleryCell: View {
    let photoId: String
    @Environment(PhotoGalleryCoordinator.self) private var coordinator
    
    private var cellSize: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let totalSpacing = CGFloat(coordinator.columnCount - 1) * 2 + 4 // spacing between cells + padding
        let availableWidth = screenWidth - totalSpacing
        return availableWidth / CGFloat(coordinator.columnCount)
    }
    
    var body: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .overlay {
                // Random gradient for visual variety
                LinearGradient(
                    colors: [
                        Color(hue: Double(photoId.hashValue % 360) / 360, saturation: 0.5, brightness: 0.8),
                        Color(hue: Double((photoId.hashValue + 60) % 360) / 360, saturation: 0.3, brightness: 0.6)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .overlay {
                Text(String(photoId.suffix(2)))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: coordinator.columnCount > 3 ? 2 : 4))
    }
}

#Preview {
    PhotoGalleryView()
}