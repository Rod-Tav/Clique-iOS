//
//  ReviewPhotosView.swift
//  Clique
//
//  Created by Rod Tavangar on 8/2/25.
//

import SwiftUI

struct ReviewPhotosView: View {
    @Environment(UserStore.self) private var userStore
    @Environment(CollectionStore.self) private var collectionStore
    @Environment(CollectionImageStore.self) private var collectionImageStore
    
    @Environment(TabViewCoordinator.self) private var tabViewCoordinator
    @Environment(CreateViewModel.self) private var viewModel
    
    @State private var currentImageIndex: Int = 0
    
    @State private var showChooseCollectionSheet: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            TopBar()
            
            // Show selected photos with thumbnail strip
            VStack {
                // Display the current selected image
                ImagePreview()
                
                ThumbnailStrip()
            }
            
            Spacer()
            
            // Bottom button
            FlowBottomButton(
                text: viewModel.selectedCollectionId == nil ? "Add to collection" : "Upload \(pluralizeWithCount(count: viewModel.selectedImages.count, singular: "Flick"))",
                buttonEnabled: viewModel.selectedCollectionId == nil || true,
                buttonLoading: false
            ) {
                if viewModel.selectedCollectionId == nil {
                    showChooseCollectionSheet = true
                } else {
                    viewModel.startUpload(userStore, tabViewCoordinator)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .primaryBackground()
        .sheet(isPresented: $showChooseCollectionSheet) {
            if let uid = userStore.currentUserId {
                ChooseCollectionView(uid: uid, collectionStore, collectionImageStore)
                    .environment(viewModel)
                    .bottomSheetModifiers()
            }
        }
    }
    
    @ViewBuilder private func TopBar() -> some View {
        TopAppBar(
            type: .small,
            leadingIcon: {
                Button {
                    tabViewCoordinator.createNavigationPath.removeLast()
                } label: {
                    IconImage(name: "arrow-left", color: .theme.iconPrimary, size: 24)
                }
            },
            header: {
                Text("Review Flicks")
                    .font(.callout.weight(.semibold))
                    .textPrimary()
            },
            trailingIcon: {
                // Empty trailing icon to balance the header
                IconImage(name: "arrow-left", color: .theme.iconPrimary, size: 24)
                    .opacity(0)
            }
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        
    }
    
    @ViewBuilder private func ImagePreview() -> some View {
        if currentImageIndex < viewModel.selectedImages.count {
            Image(uiImage: viewModel.selectedImages[currentImageIndex])
                .resizable()
                .scaledToFit()
                .frame(maxHeight: UIScreen.height * 0.5)
                .overlay(alignment: .topLeading) {
                    if let cid = viewModel.selectedCollectionClique?.id {
                        CliquePill(cid: cid, type: .newCollection)
                            .padding(16)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    if let collectionId = viewModel.selectedCollectionId {
                        Button {
                            showChooseCollectionSheet = true
                        } label: {
                            HStack(spacing: 6) {
                                IconImage(name: "collections", color: .theme.iconPrimary, size: 12)
                                
                                if let name = collectionStore.collections[collectionId]?.name {
                                    Text(name)
                                        .font(.caption.bold())
                                        .textPrimary()
                                }
                                
                                if viewModel.newCollectionVisibility == .priv {
                                    IconImage(name: "lock", color: .theme.iconPrimary, size: 12)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.theme.surfacesPrimary)
                            .roundCorners(32)
                            .padding(16)
                            .contentShape(.rect)
                        }.noHighlight()
                    }
                }
        }
    }
    
    @ViewBuilder private func ThumbnailStrip() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(viewModel.selectedImages.enumerated()), id: \.offset) { index, image in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 86)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            if currentImageIndex == index {
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.theme.textPrimary, lineWidth: 2)
                            }
                        }
                        .onTapGesture {
                            currentImageIndex = index
                        }
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(.vertical)
    }
}
