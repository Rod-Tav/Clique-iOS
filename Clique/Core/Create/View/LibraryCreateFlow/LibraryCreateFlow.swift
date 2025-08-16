//
//  LibraryCreateFlow.swift
//  Clique
//
//  Created by Rod Tavangar on 8/1/25.
//

import SwiftUI
import Toasts
import PhotosUI

struct LibraryCreateFlow: View {
    @Environment(\.presentToast) private var presentToast
    
    @Environment(AppCoordinator.self) private var appCoordinator
    
    @Environment(UserStore.self) private var userStore
    @Environment(CliqueStore.self) private var cliqueStore
    @Environment(CollectionStore.self) private var collectionStore
    @Environment(CollectionImageStore.self) private var collectionImageStore
    
    @Environment(TabViewCoordinator.self) private var tabViewCoordinator
    @Environment(CreateViewModel.self) var viewModel
    
    @State private var showChooseCollectionSheet: Bool = false
    @State private var buttonLoading: Bool = false
    @State private var currentImageIndex: Int = 0
    @State private var isProcessingPhotos: Bool = false
    @State private var shouldTriggerProcessing: Bool = false
    
    private var unprocessedCount: Int { viewModel.selectedAssets.subtracting(viewModel.processedAssets).count
    }
    
    private var totalCount: Int {
        viewModel.selectedImages.count + unprocessedCount
    }
    
    // MARK: - Body
    var body: some View {
        @Bindable var bindableViewModel = viewModel
        @Bindable var bindableTVC = tabViewCoordinator
        
        TabNavigationStack(path: $bindableTVC.createNavigationPath, useRootNavDests: false) {
            VStack(spacing: 0) {
                topBar
                
                // Photo picker as root view
                PhotoPickerContainer { context in
                    CollectionPhotosPicker(
                        shouldProcess: $shouldTriggerProcessing,
                        isProcessing: $isProcessingPhotos
                    )
                    .environment(context)
                }
            }
            .primaryBackground()
            .navigationDestination(for: CreateFlowDestination.self) { destination in
                switch destination {
                case .reviewPhotos:
                    ReviewPhotosView()
                        .environment(viewModel)
                        .environment(tabViewCoordinator)
                        .environment(userStore)
                        .environment(collectionStore)
                        .environment(collectionImageStore)
                        .toolbar(.hidden, for: .navigationBar)
                case .album(let assetCollection, let title):
                    PhotoPickerContainer { context in
                        AlbumPhotosView(
                            assetCollection: assetCollection,
                            title: title
                        )
                        .environment(context)
                    }
                    .toolbar(.hidden, for: .navigationBar)
                    .environment(viewModel)
                }
            }
        }
        .sheet(isPresented: $showChooseCollectionSheet) {
            if let uid = userStore.currentUserId {
                ChooseCollectionView(uid: uid, collectionStore, collectionImageStore)
                    .environment(viewModel)
                    .bottomSheetModifiers()
            }
        }
        .sheet(isPresented: $bindableViewModel.showNewCollectionSheet) {
            NewCollectionDetailsView()
                .environment(viewModel)
                .bottomSheetModifiers()
                .presentationDetents([.fraction(0.999)])
        }
        .onChange(of: tabViewCoordinator.createFlowInitialCollection) { _, newValue in
            guard let newValue else { return }
            viewModel.collectionToGoTo = newValue
            viewModel.selectedCollectionId = newValue.id
            viewModel.selectedCollectionClique = cliqueStore.cliques[newValue.cliqueId]
            tabViewCoordinator.createFlowInitialCollection = nil
            tabViewCoordinator.shouldOpenLibrary = false
        }
    }
    
    
    // MARK: Top Bar
    private var topBar: some View {
        TopAppBar(
            type: .small,
            leadingIcon: {
                ZStack(alignment: .leading) {
                    TrailingIcon()
                        .hidden()
                    
                    BackButton(size: 24) {
                        // Exit to previous tab
                        tabViewCoordinator.showTabBar = true
                        tabViewCoordinator.createNavigationPath = NavigationPath()
                        tabViewCoordinator.selectTab(tabViewCoordinator.previousTab)
                    }
                }
            },
            header: {
                Text("Library")
                    .font(.callout.weight(.semibold))
                    .textPrimary()
            },
            trailingIcon: {
                TrailingIcon()
            }
        )
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }
    
    @ViewBuilder private func TrailingIcon() -> some View {
        // Show count of unprocessed selections + already processed images
        if totalCount > 0 {
            // Add button
            Button {
                shouldTriggerProcessing = true
            } label: {
                HStack(spacing: 8) {
                    // Photo count
                    HStack(spacing: 4) {
                        Text("\(totalCount)")
                        
                        IconImage("images-posts", color: .theme.iconPrimary, size: 20)
                    }
                    
                    Text("Add")
                }
                .font(.caption.bold())
                .textPrimary()
            }
            .font(.callout)
            .disabled(isProcessingPhotos)
        } else {
            Button {
                tabViewCoordinator.createFlowMode = .camera
            } label: {
                IconImage("camera", color: .theme.iconPrimary, size: 24)
            }
        }
    }
}
