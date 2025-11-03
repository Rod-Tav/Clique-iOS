//
//  NewCollectionDetailsView.swift
//  Clique
//
//  Created by Rod Tavangar on 3/11/25.
//

import SwiftUI
import Toasts

struct NewCollectionDetailsView: View {
    @Environment(\.presentToast) private var presentToast
    @Environment(\.dismiss) private var dismiss
    
    @Environment(UserStore.self) private var userStore
    @Environment(CliqueStore.self) private var cliqueStore
    
    @Environment(AppCoordinator.self) private var appCoordinator
    @Environment(TabViewCoordinator.self) private var tabViewCoordinator
    
    @Environment(CreateViewModel.self) private var viewModel
    
    @FocusState private var nameIsFocused: Bool
    @FocusState private var descriptionIsFocused: Bool
    
    @State private var buttonLoading: Bool = false
    
    @State private var showCliquePicker: Bool = false
    @State private var showVisbilitySheet: Bool = false
    
    private var buttonEnabled: Bool {
        !(viewModel.newCollectionName.isEmpty || viewModel.newCollectionClique?.id == nil)
    }
    
    var body: some View {
        @Bindable var bindableVm = viewModel
        
        VStack(spacing: 16) {
            HStack(alignment: .bottom, spacing: 4) {
                Text("New Collection")
                    .font(.callout.bold())
                    .foregroundStyle(Color.theme.textPrimary)
                
                if viewModel.newCollectionVisibility == .priv {
                    IconImage(name: "lock", color: .theme.textPrimary, size: 20)
                }
            }
            
            Button {
                showCliquePicker = true
            } label: {
                Group {
                    if let cid = viewModel.newCollectionClique?.id {
                        CliquePill(cid: cid, type: .newCollection)
                    } else {
                        HStack(spacing: 8) {
                            IconImage(name: "plus", color: .theme.textSecondary, size: 16)
                                .padding(6)
                                .frame(28)
                                .roundCorners(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .inset(by: 0.75)
                                        .stroke(Color.theme.textSecondary, lineWidth: 1.5)
                                )
                            
                            Text("Pick a Clique...")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.theme.textSecondary)
                        }
                        .padding(.trailing, 8)
                        .background(Color.theme.surfacesElevatedPrimary)
                        .roundCorners(6)
                    }
                }
                .contentShape(.rect)
            }
            .maxWidth(.leading)
            
            TextField("untitled collection", text: $bindableVm.newCollectionName)
                .font(.title3.bold())
                .kerning(0.072)
                .limitTextField(to: 30, text: $bindableVm.newCollectionName)
                .focused($nameIsFocused)
                .submitLabel(.done)
                .onSubmit {
                    nameIsFocused = false
                }
            
            TextField("Add a description...", text: $bindableVm.newCollectionCaption, axis: .vertical)
                .frame(maxHeight: 100, alignment: .top)
                .font(.footnote)
                .limitTextField(to: 200, text: $bindableVm.newCollectionCaption)
                .focused($descriptionIsFocused)
                .submitLabel(.done)
                .onEnter($of: $bindableVm.newCollectionCaption) {
                    descriptionIsFocused = false
                }
            
            if descriptionIsFocused {
                Text("\(viewModel.newCollectionCaption.count) / 200")
                    .textPrimary()
                    .font(.footnote.bold())
                    .maxWidth(.trailing)
            }
            
            Spacer()

            // TODO: DRY
            TextDivider("Visibility") {
                HStack(spacing: 4) {
                    Text("Visibility")
                        .font(.footnote.weight(.medium))
                    
                    Button {
                        showVisbilitySheet = true
                    } label: {
                        IconImage(name: "help-circle", color: .theme.iconSecondary, size: 12)
                    }
                }
            }
            
            HStack(spacing: 16) {
                CollectionVisibilityButton(visibility: .priv, collectionVisibility: $bindableVm.newCollectionVisibility)
                
                CollectionVisibilityButton(visibility: .followers, collectionVisibility: $bindableVm.newCollectionVisibility)
            }
            
            Spacer()
            
            CliqueButton(
                type: .primary,
                leadingIcon: "check",
                text: "Upload \(pluralizeWithCount(count: viewModel.selectedAssets.count, singular: "Flick"))",
                textColor: buttonEnabled ? .theme.buttonContent : .theme.textSecondary,
                fontWeight: .semibold,
                buttonColor: buttonEnabled ? .theme.buttonCTA : .theme.surfacesElevatedPrimary,
                fullWidth: true,
                isLoading: buttonLoading
            ) {
                handleLibraryUpload()
            }
            .disabled(!buttonEnabled || buttonLoading)
            .padding(.bottom, 16)
            
//            Spacer().frame(8)
        }
        .padding(.horizontal, 16)
        .sheet(isPresented: $showCliquePicker) {
            if let uid = userStore.currentUserId {
                ChooseCliqueView(uid: uid, cliqueStore)
                    .presentationDetents([.fraction(0.999)])
                    .bottomSheetModifiers()
            }
        }
        .sheet(isPresented: $showVisbilitySheet) {
            VisibilitySheet()
                .presentationDetents([.medium, .fraction(0.999)])
                .bottomSheetModifiers()
        }
    }

    /// Handle upload from library flow - signal to SelectedPhotosView to process and upload
    private func handleLibraryUpload() {
        viewModel.shouldProcessAndUploadForNewCollection = true
        // SelectedPhotosView will handle dismissal and processing
    }

    @ViewBuilder private func VisibilityButton(visibility: Visibility) -> some View {
        let isSelected = viewModel.newCollectionVisibility == visibility
        
        Button {
            viewModel.newCollectionVisibility = visibility
        } label: {
            HStack(spacing: 8) {
                IconImage(name: visibility.icon, color: isSelected ? .theme.textPrimary : .theme.textSecondary, size: 20)
                
                Text(visibility.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.theme.textPrimary : Color.theme.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .maxWidth()
            .roundCorners(100)
            .overlay(
                RoundedRectangle(cornerRadius: 100)
                    .inset(by: 0.75)
                    .stroke(isSelected ? Color.theme.textPrimary : Color.theme.textSecondary, lineWidth: 1.5)
            )
            .contentShape(.rect)
        }
    }
    
    @ViewBuilder private func VisibilitySheet() -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                Text("Visibility")
                    .font(.callout.bold())
                    .textPrimary()
                    .frame(maxWidth: .infinity)
                
                ForEach(Visibility.orderedCases) { vis in
                    Button {
                        if nameIsFocused || descriptionIsFocused {
                            nameIsFocused = false
                            descriptionIsFocused = false
                        } else {
                            viewModel.newCollectionVisibility = vis
                        }
                    } label: {
                        ListSelectionItem(
                            leadingIcon: vis.icon,
                            title: vis.title,
                            description: vis.description,
                            selectedColor: .theme.textPrimary,
                            unselectedColor: .theme.textSecondary,
                            isSelected: viewModel.newCollectionVisibility == vis
                        )
                    }
                }
            }
            
            Spacer()
            
            CliqueButton(
                type: .primary,
                text: "Confirm",
                fullWidth: true
            ) {
                showVisbilitySheet = false
            }
        }
        .padding(.horizontal, 16)
    }
}

#Preview {
    NewCollectionDetailsView()
}
