//
//  UploadFlicksScreen.swift
//  Clique
//
//  Created by Rod Tavangar on 1/16/25.
//

import SwiftUI
import PhotosUI

struct UploadFlicksScreen: View {
    @Environment(TopIconFlowCoordinator.self) private var coordinator
    @Environment(CliqueCreatorFlowViewModel.self) private var viewModel
    
    @Environment(UserStore.self) private var userStore
    
    @State private var pfpItem: PhotosPickerItem?
    
    @State private var showChangeCover: Bool = false
    @State private var coverItem: PhotosPickerItem?
    
    private var pfp: UIImage? { viewModel.selectedPfpUIImage }
    private var banner: UIImage? { viewModel.selectedCoverUIImage }
    
    private var hasSelectedImage: Bool {
        viewModel.selectedPfpUIImage != nil || viewModel.selectedCoverUIImage != nil
    }
    
    var body: some View {
        @Bindable var bindableVM = viewModel
        
        VStack(spacing: 24) {
            TopTitle(
                title: "Upload your Clique flicks",
                description: "Add a profile picture and cover photo that represent your new Clique!\n\nYou can always add or change them later."
            )
            .padding(.horizontal, 16)
            
            if let currentUser = userStore.currentUser {
                ScrollView { // hack for sizing
                    EditCliqueHeader(
                        selectedPfpUIImage: $bindableVM.selectedPfpUIImage,
                        selectedCoverUIImage: $bindableVM.selectedCoverUIImage,
                        cliqueName: $bindableVM.cliqueName,
                        cliqueBio: $bindableVM.cliqueBio,
                        members: [currentUser] + viewModel.invitedMembers
                    )
                }
            }
        }
        .onChange(of: [viewModel.selectedPfpUIImage, viewModel.selectedCoverUIImage], initial: true) {
            coordinator.highlightNextBar = hasSelectedImage
            coordinator.bottomButton = { AnyView(BottomButton()) }
        }
    }
}

// MARK: - Bottom Button
extension UploadFlicksScreen {
    @ViewBuilder private func BottomButton() -> some View {
        FlowBottomButton(
            text: hasSelectedImage ? "Done" : "Skip",
            buttonEnabled: !viewModel.cliqueName.isEmpty
        ) {
            bottomButtonAction()
        }
        
        
//        CliqueButton(
//            type: .primary,
//            text: hasSelectedImage ? "Done" : "Skip",
//            textColor: hasSelectedImage ? .theme.buttonContent : .theme.textPrimary,
//            fontWeight: hasSelectedImage ? .bold : .regular,
//            buttonColor: hasSelectedImage ? .theme.buttonCTA : .theme.surfacesElevatedPrimary,
//            fullWidth: true
//        ) { bottomButtonAction() }
    }
    
    private func bottomButtonAction() {
        coordinator.highlightNextBar = false
        coordinator.currentIconStep += 1
        coordinator.path.append(4)
    }
}

#Preview {
    UploadFlicksScreen()
        .padding(.top, 24)
        .frameTop()
        .environment(TopIconFlowCoordinator())
        .environment(CliqueCreatorFlowViewModel())
}
