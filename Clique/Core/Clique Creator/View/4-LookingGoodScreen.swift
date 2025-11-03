////
////  LookingGoodScreen.swift
////  Clique
////
////  Created by Rod Tavangar on 1/16/25.
////
//
//import SwiftUI
//import PhotosUI
//import Toasts
//
//// TODO: header is copy paste of the screen before
//struct LookingGoodScreen: View {
//    @Environment(\.presentToast) private var presentToast
//    
//    @Environment(UserStore.self) private var userStore
//    @Environment(CliqueStore.self) private var cliqueStore
//    
//    @Environment(TopIconFlowCoordinator.self) private var coordinator
//    @Environment(CliqueCreatorFlowViewModel.self) private var viewModel
//    
//    @State private var isLoading: Bool = false
//    @State private var showAddMembersSheet: Bool = false
//    
//    @State private var pfpItem: PhotosPickerItem?
//    
//    @State private var coverItem: PhotosPickerItem?
//    
//    private var pfp: UIImage? { viewModel.selectedPfpUIImage }
//    private var banner: UIImage? { viewModel.selectedCoverUIImage }
//    
//    private var hasSelectedImage: Bool {
//        viewModel.selectedPfpUIImage != nil || viewModel.selectedCoverUIImage != nil
//    }
//    
//    // MARK: - Body
//    var body: some View {
//        @Bindable var bindableVM = viewModel
//        
//        VStack(spacing: 24) {
//            TopTitle(
//                title: "Looking good!",
//                description: "Almost there! Make any final adjustments to your brand new Clique here."
//            )
//            
//            ScrollView {
//                if let currentUser = userStore.currentUser {
//                    EditCliqueHeader(
//                        selectedPfpUIImage: $bindableVM.selectedPfpUIImage,
//                        selectedCoverUIImage: $bindableVM.selectedCoverUIImage,
//                        cliqueName: $bindableVM.cliqueName,
//                        cliqueBio: $bindableVM.cliqueBio,
//                        members: [currentUser] + viewModel.invitedMembers
//                    )
//                }
//                
//                VStack(spacing: 16) {
//                    HStack {
//                        Text("Inviting \(pluralizeWithCount(count: viewModel.invitedMembers.count, singular: "member"))")
//                            .font(.body.bold())
//                            .textPrimary()
//                        
//                        Spacer()
//                        
//                        SmallCTA(
//                            type: .secondary,
//                            leadingIcon: "plus",
//                            text: "Add"
//                        )
//                        .onHighPriorityTap {
//                            showAddMembersSheet = true
//                        }
//                    }
//                    
//                    VStack(spacing: 16) {
//                        ForEach(viewModel.invitedMembers) { user in
//                            HStack {
//                                UserListCellView(uid: user.id, type: .large)
//                                
//                                Spacer()
//                                
//                                IconImage(name: "x-icon", color: .theme.iconSecondary, size: 16)
//                                    .onHighPriorityTap {
//                                        viewModel.invitedMembers.removeAll(where: { $0.id == user.id })
//                                    }
//                            }
//                        }
//                    }
//                }
//                .padding(.horizontal, 24)
//            }
//            .sheet(isPresented: $showAddMembersSheet) {
//                InviteMembersScreen()
//                    .padding(.horizontal, 16)
//                    .presentationDetents([.fraction(0.999)])
//                    .bottomSheetModifiers()
//            }
//        }
//        .onChange(of: isLoading, initial: true) { // TODO: should be bound or whatever. also these shouldn't be anyviews
//            coordinator.bottomButton = { AnyView(BottomButton()) }
//        }
//    }
//}
//
//// MARK: - Bottom Button
//extension LookingGoodScreen {
//    @ViewBuilder private func BottomButton() -> some View {
//        FlowBottomButton(
//            text: "Create Clique",
//            buttonEnabled: !viewModel.invitedMembers.isEmpty,
//            buttonLoading: isLoading
//        ) { bottomButtonAction() }
//    }
//    
//    private func bottomButtonAction() {
//        Task {
//            do {
//                isLoading = true
//                try await viewModel.createClique()
//                
//                userStore.users[userStore.currentUserId!]?.numCliques += 1
//                
//                cliqueStore.updateClique(viewModel.createdClique!)
//                
//                cliqueStore.cliques[viewModel.createdClique!.id]?.leader = userStore.currentUserId!
//                
//                coordinator.iconBgColor = .theme.green
//                coordinator.path.append(5)
//                isLoading = false
//            } catch(let error) {
//                print(error)
//                print("create clique failed")
//                presentToast(Toasts.somethingWentWrong)
//                isLoading = false
//            }
//        }
//    }
//}
//
//#Preview {
//    LookingGoodScreen()
//        .padding(.top, 24)
//        .padding(.bottom, 8)
////        .padding(.horizontal, 16)
//        .frameTop()
//        .environment(TopIconFlowCoordinator())
//        .environment(CliqueCreatorFlowViewModel())
//}
