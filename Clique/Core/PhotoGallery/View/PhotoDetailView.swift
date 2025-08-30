//
//  PhotoDetailView.swift
//  Clique
//
//  Created by Assistant on 12/29/24.
//

import SwiftUI

struct PhotoDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PhotoGalleryCoordinator.self) private var coordinator
    
    let photoId: String
    
    // Mock photo IDs for carousel
    let allPhotoIds = Array(1...100).map { "photo_\($0)" }
    
    @State private var currentPhotoId: String
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging: Bool = false
    @State private var opacity: CGFloat = 1
    
    init(photoId: String) {
        self.photoId = photoId
        self._currentPhotoId = State(initialValue: photoId)
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()
                .opacity(opacity)
            
            VStack(spacing: 0) {
                // Top Bar
                topBar
                    .opacity(opacity)
                
                Spacer()
                
                // Main Image Area
                imagePreview
                
                Spacer()
                
                // Bottom Carousel
                bottomCarousel
                    .opacity(opacity)
            }
        }
        .navigationBarHidden(true)
        .offset(dragOffset)
        .gesture(dismissGesture)
    }
    
    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text("Photo Gallery")
                    .font(.callout.bold())
                    .foregroundStyle(.white)
                
                Text(currentPhotoId)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            Spacer()
            
            Menu {
                Button {
                    // Share action
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                
                Button {
                    // Save action
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    private var imagePreview: some View {
        TabView(selection: $currentPhotoId) {
            ForEach(allPhotoIds, id: \.self) { photoId in
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay {
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
                            Text(photoId)
                                .font(.largeTitle)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .aspectRatio(1, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.horizontal, 16)
                }
                .tag(photoId)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .frame(maxHeight: UIScreen.main.bounds.width)
    }
    
    private var bottomCarousel: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(allPhotoIds, id: \.self) { photoId in
                        carouselItem(photoId)
                            .id(photoId)
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 80)
            .onChange(of: currentPhotoId) { _, newValue in
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
            .onAppear {
                proxy.scrollTo(currentPhotoId, anchor: .center)
            }
        }
    }
    
    @ViewBuilder
    private func carouselItem(_ photoId: String) -> some View {
        let isSelected = photoId == currentPhotoId
        let size: CGFloat = isSelected ? 70 : 60
        
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .overlay {
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
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.white, lineWidth: 2)
                }
            }
            .scaleEffect(isSelected ? 1.0 : 0.95)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
            .onTapGesture {
                withAnimation {
                    currentPhotoId = photoId
                }
            }
    }
    
    private var dismissGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if abs(value.translation.width) < abs(value.translation.height) {
                    isDragging = true
                    dragOffset = value.translation
                    
                    // Calculate opacity based on drag distance
                    let progress = abs(value.translation.height) / 200
                    opacity = max(0.3, 1 - progress)
                }
            }
            .onEnded { value in
                if isDragging {
                    let shouldDismiss = abs(value.translation.height) > 100 ||
                                       abs(value.velocity.height) > 500
                    
                    if shouldDismiss {
                        dismiss()
                    } else {
                        withAnimation(.interactiveSpring()) {
                            dragOffset = .zero
                            opacity = 1
                        }
                    }
                    isDragging = false
                }
            }
    }
}

#Preview {
    PhotoDetailView(photoId: "photo_1")
        .environment(PhotoGalleryCoordinator())
}