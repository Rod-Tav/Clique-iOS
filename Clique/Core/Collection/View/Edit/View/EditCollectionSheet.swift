//
//  EditCollectionSheet.swift
//  Clique
//
//  Created by Rod Tavangar on 3/25/25.
//

import SwiftUI
import Toasts

struct EditCollectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentToast) private var presentToast
    
    @Environment(CollectionStore.self) private var collectionStore
    @Environment(CollectionImageStore.self) private var collectionImageStore
    
    @State var viewModel: EditCollectionViewModel
    
    var clique: Clique?
    var members: [User]
    
    @State private var showVisibilityAlert: Bool = false
    @State private var showCoverPhotoPicker: Bool = false
    @State private var buttonLoading: Bool = false
    
    @FocusState private var nameIsFocused: Bool
    @FocusState private var descriptionIsFocused: Bool
    
    init(clique: Clique?, members: [User], collection: ClCollection) {
        self.clique = clique
        self.members = members
        self.viewModel = .init(collection: collection)
    }
    
    var body: some View {
        @Bindable var bindableVM = viewModel
        
        if let clique {
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    Text("Edit Collection")
                        .textPrimary().bold()
                    
                    CoverPhotoView()
                    
                    HStack(spacing: 0) {
                        CliquePill(clique.id, type: .feedCell)
                        
                        Spacer()
                        
                        CliqueCircularMembersView(members: members, type: .cliqueProfile)
                    }
                    
                    HStack(spacing: 4) {
                        TextField(viewModel.name, text: $bindableVM.name)
                            .textPrimary()
                            .font(.title3.bold())
                            .kerning(0.072)
                            .limitTextField(to: 30, text: $bindableVM.name)
                            .focused($nameIsFocused)
                            .submitLabel(.done)
                            .onSubmit {
                                nameIsFocused = false
                            }
                        
                        if viewModel.visibility == .priv {
                            IconImage("lock", color: .theme.iconPrimary, size: 20)
                        }
                    }
                    
                    TextField(viewModel.description.isEmpty ? "Add description" : viewModel.description, text: $bindableVM.description, axis: .vertical)
                        .textPrimary()
                        .submitLabel(.done)
                        .limitTextField(to: 200, text: $bindableVM.description)
                        .focused($descriptionIsFocused)
                        .submitLabel(.done)
                        .onEnter($of: $bindableVM.description) {
                            descriptionIsFocused = false
                        }
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    TextDivider("Visibility") {
                        HStack(spacing: 4) {
                            Text("Visibility")
                                .font(.footnote.weight(.medium))
                                .lineLimit(1)
                                .layoutPriority(1)
                                .foregroundStyle(Color.theme.textSecondary)
                            
                            Button {
                                showVisibilityAlert = true
                            } label: {
                                IconImage("help-circle", color: .theme.textSecondary, size: 12)
                            }
                        }
                    }
                    
                    HStack(spacing: 16) {
                        CollectionVisibilityButton(visibility: .priv, collectionVisibility: $bindableVM.visibility)
                        
                        CollectionVisibilityButton(visibility: .followers, collectionVisibility: $bindableVM.visibility)
                    }
                    
                }
                
                Spacer()
                
                CliqueButton(
                    type: .primary,
                    leadingIcon: "check",
                    text: "Save",
                    fullWidth: true,
                    isLoading: buttonLoading
                ) {
                    buttonLoading = true
                    
                    Task {
                        do {
                            let updatedCollection = try await viewModel.editCollection()
                            
                            collectionStore.updateCollection(updatedCollection, forceUpdateURL: viewModel.coverPhoto != nil, collectionImageStore)
                            
                            await MainActor.run {
                                buttonLoading = false
                                dismiss()
                            }
                        } catch {
                            await MainActor.run {
                                buttonLoading = false
                            }
                            presentToast(Toasts.somethingWentWrong)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .alert("Private: The collection is only visible to members of your clique. Followers: The collection is visible to all followers of your clique's members.", isPresented: $showVisibilityAlert) {
                
                Button("Dismiss", role: .cancel) { }
            }
        }
        
    }
    
    @ViewBuilder private func CoverPhotoView() -> some View {
        @Bindable var bindableVM = viewModel
        
        CollectionPreviewWithGridBg(
            width: UIScreen.width - 32,
            image: {
                if viewModel.coverPhoto != nil {
                    Image(uiImage: viewModel.coverPhoto!)
                        .collectionCoverPreviewModifiers()
                } else {
                    CollectionEditCoverPhotoAsyncImage(urls: viewModel.photoUrls, quality: .medium)
                }
            }
        )
        .onHighPriorityTap { showCoverPhotoPicker = true }
        .cropImagePicker(
            type: .banner(width: UIScreen.width),
            show: $showCoverPhotoPicker,
            croppedUIImage: $bindableVM.coverPhoto
        )
        .overlayAddChangeCover(
            isImageChosen: viewModel.coverPhoto != nil || viewModel.coverPhoto != nil,
            showPicker: { showCoverPhotoPicker = true },
            removeCover: { viewModel.coverPhoto = nil }
        )
    }
}
