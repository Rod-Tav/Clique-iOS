//
//  EditCliqueHeader.swift
//  Clique
//
//  Created by Rod Tavangar on 2/6/25.
//

import SwiftUI

struct EditCliqueHeader: View {
    @Environment(UserStore.self) private var userStore
    
//    @Environment(CliqueCreatorFlowViewModel.self) private var viewModel
    
    @Binding var selectedPfpUIImage: UIImage?
    @Binding var selectedCoverUIImage: UIImage?
    @Binding var cliqueName: String
    @Binding var cliqueBio: String
    
    @State private var showChangePfp: Bool = false
    @State private var showChangeCover: Bool = false
    
    @FocusState private var focusedField: CliqueInfoFocusedField?
    
    let members: [User]
    var ogCliquePic: PhotoUrls?
    var ogCliqueBanner: PhotoUrls?
    var leader: User?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Banner()
                    .onHighPriorityTap { showChangeCover = true }
                    .cropImagePicker(
                        type: .banner(width: UIScreen.width),
                        show: $showChangeCover,
                        croppedUIImage: $selectedCoverUIImage
                    )
                    .overlayAddChangeCover(
                        isImageChosen: selectedCoverUIImage != nil,
                        showPicker: {
                            showChangeCover = true
                        },
                        removeCover: {
                            selectedCoverUIImage = nil
                        }
                    )
                
                PfpAndMembers()
                    .padding(.horizontal, 24)
                    .padding(.top, -CliquePfpViewType.cliqueProfile.size.height / 2)
            }
            
            CliqueInfo()
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
    }
    
    // MARK: - Banner
    @ViewBuilder private func Banner() -> some View {
        if let cover = selectedCoverUIImage {
            Image(uiImage: cover)
                .expandedBannerModifiers(type: .clique)
        } else if let ogCliqueBanner {
            ExpandedBannerAsyncImage(banner: ogCliqueBanner, type: .clique, quality: .high)
        } else {
            Image("default-gradient")
                .generalExpandedBannerModifiers()
        }
    }
    
    // MARK: - Pfp and Banner
    @ViewBuilder private func PfpAndMembers() -> some View {
//        @Bindable var bindableVm = viewModel
        
        HStack(spacing: 0) {
            Pfp()
                .cropImagePicker(
                    type: .cliquePfp,
                    show: $showChangePfp,
                    croppedUIImage: $selectedPfpUIImage
                )
            
            Spacer()
            
            if userStore.currentUser != nil {
                CliqueCircularMembersView(members: members, memberLimit: 5, type: .large)
            }
        }
    }
    
    // MARK: - Pfp
    @ViewBuilder private func Pfp() -> some View {
        Group {
            if let pfp = selectedPfpUIImage {
                CliquePfpView(pfp: pfp, type: .cliqueProfile)
            } else if let ogCliquePic {
                CliquePfpAsyncView(pfp: ogCliquePic, type: .cliqueProfile, quality: .low)
            } else {
                CliquePfpView(pfp: "default-gradient", type: .cliqueProfile)
            }
        }
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(Color.theme.surfacesPrimary)
                .frame(20)
                .overlay {
                    IconImage(name: "plus", color: .theme.iconSecondary, size: 12)
                }
                .rotationEffect(.degrees(selectedPfpUIImage == nil ? 0 : 45))
                .offset(x: 5, y: -5)
                .onHighPriorityTap {
                    if selectedPfpUIImage == nil {
                        showChangePfp = true
                    } else {
                        selectedPfpUIImage = nil
                    }
                }
        }
        // desired behavior might be to not open the picker when xmark is tapped, but it's a feature not a bug
        .onSimultaneousTap { showChangePfp = true }
    }
    
    // MARK: - Info
    @ViewBuilder  private func CliqueInfo() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    TextField("", text: $cliqueName, prompt: Text("Add a name...").foregroundStyle(Color.theme.textTertiary))
                        .font(.title2.bold())
                        .kerning(0.0748)
                        .textPrimary()
                        .focused($focusedField, equals: .cliqueName)
                        .limitTextField(to: 50, text: $cliqueName)
                        .submitLabel(.done)
                        .onSubmit {
                            focusedField = .none
                        }
                        
//                    Text("\(cliqueName)")
//                        .font(.title2.bold())
                    
                    Spacer()
                    
                    SmallCTA(
                        type: .primary,
                        leadingIcon: "crown-leader",
                        text: "Leader",
                        action: {}
                    ).buttonStyle(.noHighlight)
                }
                
                CliqueLeaderAndCreation()
            }
            
//            if !cliqueBio.isEmpty {
                TextField("", text: $cliqueBio, prompt: Text("Add a bio...").foregroundStyle(Color.theme.textTertiary))
                    .font(.footnote)
                    .textPrimary()
                    .focused($focusedField, equals: .cliqueBio)
                    .limitTextField(to: 50, text: $cliqueBio)
                    .submitLabel(.done)
                    .onSubmit {
                        focusedField = .none
                    }
                
//                Text(cliqueBio)
//                    .fixedSize(horizontal: false, vertical: true)
//                    .font(.caption)
//            }
        }
    }
    
    // MARK: - Leader and Creation
    @ViewBuilder private func CliqueLeaderAndCreation() -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 2) {
                IconImage(name: "crown-leader", color: Color.theme.iconSecondary, size: 14)
                
                if let leader {
                    Text("@\(leader.username)" )
                        .font(.caption)
                        .textSecondary()
                }
            }
            
            HStack(spacing: 4) {
                IconImage(name: "calendar", color: Color.theme.iconSecondary, size: 14)
                
                Text("est. \(formatDateMMMMyyyy(Date()))")
                    .font(.caption)
                    .textSecondary()
            }
        }
    }
}
