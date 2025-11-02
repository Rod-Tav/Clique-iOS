//
//  CameraCreateFlow.swift
//  Clique
//
//  Created by Rod Tavangar on 3/9/25.
//

import SwiftUI
import Toasts
import UserNotifications
import PhotosUI

struct CameraCreateFlow: View {
    @Environment(\.presentToast) private var presentToast
    
    @Environment(AppCoordinator.self) private var appCoordinator
    
    @Environment(UserStore.self) private var userStore
    @Environment(CliqueStore.self) private var cliqueStore
    @Environment(CollectionStore.self) private var collectionStore
    @Environment(CollectionImageStore.self) private var collectionImageStore
    
    @Environment(TabViewCoordinator.self) private var tabViewCoordinator
    
    @StateObject private var model = CameraDataModel()
    @StateObject private var volumeHandler = VolumeButtonHandler()
    
    @Environment(CreateViewModel.self) var viewModel
    
    @State private var showChooseCollectionSheet: Bool = false
    
    @State private var buttonLoading: Bool = false
    
    @State private var isFront: Bool = false
    
    @State private var hasPressedShutter: Bool = false
    
    // MARK: - Body
    var body: some View {
        @Bindable var bindableViewModel = viewModel
        @Bindable var bindableTVC = tabViewCoordinator
        
        TabNavigationStack(path: $bindableTVC.createNavigationPath, useRootNavDests: false) {
            VStack(spacing: 0) {
                TopBar()
                
                Spacer()
                
                CameraPreview()
                
                Spacer()
                
                if model.capturedImage != nil {
                    bottomButton
                } else {
                    bottomBar
                }
            }
            .navigationDestination(for: CreateFlowDestination.self) { destination in
                if destination == .reviewPhotos {
                    ReviewPhotosView()
                        .environment(viewModel)
                        .environment(tabViewCoordinator)
                        .environment(userStore)
                        .environment(collectionStore)
                        .environment(collectionImageStore)
                        .toolbar(.hidden, for: .navigationBar)
                }
            }
            .background(Color.theme.dark)
        }
        .onReceive(of: .cameraReset) { _ in
            model.camera.stop()
            model.capturedImage = nil
        }
        .task {
            await model.camera.start()
        }
        .onChange(of: tabViewCoordinator.createFlowMode) { oldMode, newMode in
            // Stop camera when switching away from camera mode to prevent orientation observers from running
            if oldMode == .camera && newMode != .camera {
                model.camera.stop()
            }
        }
        .onDisappear {
            // Ensure camera stops when view disappears (tab switch, dismissal, etc.)
            model.camera.stop()
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
                .presentationDetents(viewModel.fromLibrary ? [.fraction(0.999)] : [.fraction(0.6)])
        }
        .onChange(of: viewModel.selectedImages) { _, newImages in
            // Process newly selected images from the custom photo picker
            if !newImages.isEmpty && viewModel.photoDatePairs.isEmpty {
                Task {
                    await processSelectedPhotos()
                    tabViewCoordinator.createNavigationPath.append(CreateFlowDestination.reviewPhotos)
                }
            }
        }
        .onChange(of: tabViewCoordinator.createFlowInitialClique, initial: true) { _, newValue in
            // Handle clique context (fires on initial value and changes)
            guard let newValue else { return }
            viewModel.newCollectionClique = newValue
            tabViewCoordinator.createFlowInitialClique = nil
        }
        .onChange(of: tabViewCoordinator.createFlowInitialCollection, initial: true) { _, newValue in
            // Handle collection context (fires on initial value and changes)
            guard let newValue else { return }
            viewModel.collectionToGoTo = newValue
            viewModel.selectedCollectionId = newValue.id
            viewModel.selectedCollectionClique = cliqueStore.cliques[newValue.cliqueId]
            if tabViewCoordinator.shouldOpenLibrary {
                tabViewCoordinator.createFlowMode = .library
            }
            tabViewCoordinator.createFlowInitialCollection = nil
            tabViewCoordinator.shouldOpenLibrary = false
        }
    }
    
    // MARK: - Top Bar
    @ViewBuilder private func TopBar() -> some View {
        TopAppBar(
            type: .small,
            leadingIcon: {
                HStack(spacing: 0) {
                    ZStack(alignment: .leading) {
                        Button {
                            if viewModel.capturedUIImage != nil {
                                // Clear captured image and go back to camera
                                model.capturedImage = nil
                                viewModel.capturedUIImage = nil
                                viewModel.selectedImages.removeAll()
                                viewModel.selectedImagesDates.removeAll()
                                viewModel.photoDatePairs.removeAll()
                                viewModel.preparedImageVariants.removeAll()
                            } else {
                                // Exit to previous tab
                                tabViewCoordinator.showTabBar = true
                                tabViewCoordinator.createNavigationPath = NavigationPath()
                                tabViewCoordinator.selectTab(tabViewCoordinator.previousTab)
                                model.camera.stop()
                            }
                        } label: {
                            IconImage("arrow-left", color: .theme.shadesWhite95, size: 24)
                        }
                        
                        if !viewModel.selectedImages.isEmpty {
                            HStack(spacing: 4) {
                                IconImage("images-posts", color: .theme.shadesWhite95, size: 20)
                                
                                Text("\(viewModel.selectedImages.count)")
                                    .font(.caption.bold())
                                    .foregroundStyle(Color.theme.white)
                            }
                            .hidden()
                        }
                    }
                }
            },
            header: {
                Image("short-wordmark")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 28)
            },
            trailingIcon: {
                if viewModel.selectedImages.isEmpty {
                    Spacer().frame(24)
                } else {
                    HStack(spacing: 4) {
                        IconImage("images-posts", color: .theme.shadesWhite95, size: 20)
                        
                        Text("\(viewModel.selectedImages.count)")
                            .font(.caption.bold())
                            .foregroundStyle(Color.theme.white)
                    }
                }
            }
        )
        .padding(.horizontal, 24)
    }
    
    
    // MARK: - Image Preview
    @ViewBuilder private func CameraPreview() -> some View {
        ZStack {
            if let capturedImage = model.capturedImage {
                Image(uiImage: capturedImage)
                    .resizable()
                    .scaledToFit()
                    .frameRatio(width: UIScreen.width, ratio: (3.0 / 4.0))
                    .roundCorners(16)
                    .onAppear {
                        viewModel.capturedUIImage = capturedImage
                        viewModel.selectedImages = [capturedImage]
                        viewModel.selectedImagesDates = [Date()]
                        
                        guard let (photoData, imageVariant) = prepareUIImage(capturedImage) else { return }

                        let photoPair = Components.Schemas.PhotoVideoDate(photo: photoData, video: nil, mediaType: .PHOTO, dateCreated: convertFromDate(Date()))

                        viewModel.photoDatePairs.append(photoPair)
                        viewModel.preparedImageVariants.append(imageVariant)
                        
                        hasPressedShutter = false
                    }
                    .overlay(alignment: .topTrailing) {
                        Button {
                            model.capturedImage = nil
                            viewModel.capturedUIImage = nil
                            viewModel.selectedImages.removeAll()
                            viewModel.selectedImagesDates.removeAll()
                            viewModel.photoDatePairs.removeAll()
                            viewModel.preparedImageVariants.removeAll()
                        } label: {
                            HStack(spacing: 4) {
                                IconImage("x-icon", color: .theme.iconPrimary, size: 12)
                            }
                            .padding(6)
                            .background(Color.theme.surfacesPrimary)
                            .roundCorners(32)
                        }
                        .padding(16)
                    }
                    .overlay(alignment: .topLeading) {
                        if let cid = viewModel.selectedCollectionClique?.id {
                            CliquePill(cid, type: .newCollection)
                                .padding(16)
                        }
                    }
                    .overlay(alignment: .bottomLeading) {
                        if let collectionId = viewModel.selectedCollectionId {
                            Button {
                                showChooseCollectionSheet = true
                            } label: {
                                HStack(spacing: 6) {
                                    IconImage("collections", color: .theme.textPrimary, size: 12)
                                    
                                    if let name = collectionStore.collections[collectionId]?.name {
                                        Text(name)
                                            .font(.caption.bold())
                                            .foregroundStyle(Color.theme.textPrimary)
                                    }
                                    
                                    if viewModel.newCollectionVisibility == .priv {
                                        IconImage("lock", color: .theme.textPrimary, size: 12)
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
            } else {
                let isPortrait = model.deviceOrientation == .portrait || model.deviceOrientation == .portraitUpsideDown
                
                let width = UIScreen.width
                let height = UIScreen.width * (4.0 / 3.0)
                
                ViewfinderView(image: $model.viewfinderImage, zoomFactor: $model.zoomFactor)
                    .frame(
                        width: isPortrait ? width : height,
                        height: isPortrait ? height : width
                    )
                    .roundCorners(16)
                    .overlay(alignment: isFront && model.deviceOrientation != .portrait ? .top : .bottom) {
                        FlashAndZoom()
                            .scaleEffect(
                                x: isFront && model.deviceOrientation != .portrait ? -1 : 1,
                                y: isFront && model.deviceOrientation != .portrait ? -1 : 1
                            )
                            .padding(isFront && model.deviceOrientation != .portrait ? .top : .bottom, 17.5)
                    }
                    .rotationEffect(rotationAngle(for: model.deviceOrientation))
                    .onTapGesture(count: 2) {
                        model.switchCaptureDevice()
                        isFront.toggle()
                    }
                    .onAppear {
                        hasPressedShutter = false
                    }
            }
        }
        .onAppear {
            volumeHandler.shouldHandlePress = {
                model.capturedImage == nil
            }
            volumeHandler.onAnyVolumePress = {
                model.takePhoto()
            }
        }
    }
    
    // MARK: - Zoom Buttons
    private func FlashAndZoom() -> some View {
        HStack {
            FlashButton()
            
            //            Spacer()
            //
            //            ForEach(model.availableZoomLevels, id: \.self) { zoom in
            //                Button {
            //                    model.zoomFactor = zoom
            //                } label: {
            //                    Text(zoomLabel(for: zoom))
            //                        .font(.caption.bold())
            //                        .foregroundStyle(model.zoomFactor == zoom ? Color.theme.gold : Color.theme.shadesWhite95)
            //                        .frame(32)
            //                        .background(Color.theme.black)
            //                        .clipShape(.circle)
            //                }
            //            }
            //
            //            Spacer()
            //
            //            Spacer().frame(24)
        }
        .maxWidth(.leading)
        .padding(.horizontal, 24)
    }
    
    // MARK: - Bottom Button
    private var bottomButton: some View {
        CliqueButton(
            type: .primary,
            leadingIcon: "arrow-right",
            text: "Continue",
            fullWidth: true,
            isLoading: buttonLoading
        ) {
            // Navigate to review when captured image is processed
            tabViewCoordinator.createNavigationPath.append(CreateFlowDestination.reviewPhotos)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 64)
    }
    
    // MARK: - Bottom Bar
    private var bottomBar: some View {
        HStack {
            Button {
                tabViewCoordinator.createFlowMode = .library
            } label: {
                IconImage("library", color: .theme.white, size: 32)
                    .padding(8)
                    .frame(48)
                    .background(Color.theme.shadesWhite15)
                    .roundCorners(16)
            }
            .noHighlight()
            
            Spacer()
            
            Button {
                model.takePhoto()
                viewModel.fromLibrary = false
                hasPressedShutter = true
            } label: {
                Group {
                    if hasPressedShutter {
                        CliqueProgressView(forceLight: true, size: 64)
                        
                    } else {
                        Image("shutter")
                            .resizable()
                    }
                }
                .frame(80)
            }
            .noHighlight()
            .disabled(hasPressedShutter)
            
            Spacer()
            
            Button {
                model.switchCaptureDevice()
                isFront.toggle()
            } label: {
                IconImage("switch", color: .theme.white, size: 24)
                    .padding(12)
                    .frame(48)
                    .background(Color.theme.shadesWhite15)
                    .clipShape(.circle)
            }
        }
        .padding(.horizontal, 48)
    }
    
    private func FlashButton() -> some View {
        Button {
            switch model.flashMode {
            case .off:
                model.flashMode = .on
            case .on:
                model.flashMode = .auto
            case .auto:
                model.flashMode = .off
            @unknown default:
                model.flashMode = .off
            }
        } label: {
            IconImage(
                model.flashMode == .off ? "no-flash" : "flash",
                color: model.flashMode == .auto ? .theme.gold : .theme.shadesWhite95,
                size: 24
            )
        }
    }
    
    private func zoomLabel(for zoom: CGFloat) -> String {
        if zoom.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(zoom))x"
        } else {
            return String(format: "%.1fx", zoom)
        }
    }
    
    private func rotationAngle(for orientation: UIDeviceOrientation) -> Angle {
        switch orientation {
        case .landscapeLeft:
            return .degrees(isFront ? -90 : 90)
        case .landscapeRight:
            return .degrees(isFront ? 90 : -90)
        default:
            return .degrees(0)
        }
    }
    
    
    // without auto:
    //    private func flashToggleButton() -> some View {
    //        Button(action: {
    //            // Toggle between .off and .on
    //            model.flashMode = (model.flashMode == .off) ? .on : .off
    //        }) {
    //            // Show icon based on current flash mode
    //            Image(systemName: model.flashMode == .on ? "bolt.fill" : "bolt.slash")
    //                .resizable()
    //                .frame(width: 32, height: 32)
    //                .foregroundColor(.white)
    //        }
    //    }
}


#Preview {
    CameraCreateFlow()
}
