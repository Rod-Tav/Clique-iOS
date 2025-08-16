////
////  CliqueCreatorFlow.swift
////  Clique
////
////  Created by Rod Tavangar on 1/16/25.
////
//
//import SwiftUI
//import Toasts
//
//struct CliqueCreatorFlow: View {
//    @Environment(\.safeAreaInsets) private var safeAreaInsets
//    @Environment(\.dismiss) private var dismiss
//    @Environment(\.colorScheme) private var colorScheme
//    
//    @Environment(UserStore.self) private var userStore
//    
//    @Environment(TabViewCoordinator.self) private var tabViewCoordinator
//    
//    @State private var coordinator = TopIconFlowCoordinator()
//    @State private var viewModel = CliqueCreatorFlowViewModel()
//    
//    var body: some View {
//        VStack(spacing: 0) {
//            VStack(spacing: 24) {
//                TopBar()
//                
//                NavStack()
//            }
//            .onTapGesture { viewModel.triggerDismissKeyboard.toggle() }
//            
//            coordinator.bottomButton()
//                .padding(.horizontal, 16)
//                .padding(.top, /*coordinator.currentIconStep == 1 ? 80 :*/ 32)
//            //                .padding(.bottom, 32)
//                .background(colorScheme == .light ? Gradients.buttonBgLight : Gradients.buttonBgDark)
//        }
//        //        .ignoresSafeArea(edges: .bottom)
//        .primaryBackground()
//        .onChange(of: viewModel.triggerDismiss) {
//            dismiss()
//        }
//    }
//}
//
//// MARK: - Top Bar
//extension CliqueCreatorFlow {
//    @ViewBuilder private func TopBar() -> some View {
//        TopAppBar(
//            type: .small,
//            leadingIcon: {
//                Button {
//                    if coordinator.path.count == 4 {
//                        dismiss()
//                        tabViewCoordinator.navigate(to: viewModel.createdClique!)
//                        viewModel.reset()
//                    } else {
//                        if coordinator.currentIconStep == 1 && coordinator.path.isEmpty {
//                            dismiss()
//                        } else if coordinator.currentIconStep > 1 {
//                            coordinator.currentIconStep -= 1
//                        }
//                        
//                        if !coordinator.path.isEmpty {
//                            coordinator.path.removeLast()
//                        }
//                    }
//                } label: {
//                    IconImage(coordinator.path.count == 4 ? "x-icon" : "arrow-left", color: .theme.iconSecondary, size: 24)
//                }.buttonStyle(.noHighlight)
//            },
//            header: {
//                TopIconBar(icons: ["2-user", "pen", "camera", "check"])
//                    .environment(coordinator)
//            },
//            trailingIcon: { Spacer().frame(24) }
//        )
//        .padding(.top, 8)
//        .padding(.horizontal, 16)
//    }
//}
//
//// MARK: - Nav Stack
//extension CliqueCreatorFlow {
//    @ViewBuilder private func NavStack() -> some View {
//        NavigationStack(path: $coordinator.path) {
//            InviteMembersScreen()
//                .padding(.horizontal, 16)
////                .safeAreaPadding(.bottom, 32 + safeAreaInsets.bottom)
//                .environment(coordinator)
//                .environment(viewModel)
//                .primaryBackground()
//                .navigationDestination(for: Int.self) { dest in
//                    Group {
//                        if dest == 2 {
//                            NameYourCliqueScreen()
//                                .padding(.top, 24)
//                                .padding(.horizontal, 16)
//                                .frameTop()
//                        } else if dest == 3 {
//                            UploadFlicksScreen()
//                                .padding(.top, 24)
//                                .frameTop()
//                        } else if dest == 4 {
//                            LookingGoodScreen()
//                                .padding(.top, 24)
//                                .frameTop()
//                        } else if dest == 5 {
//                            CliqueCreatedScreen()
//                        }
//                    }
//                    .environment(coordinator)
//                    .environment(viewModel)
//                    .navigationBarBackButtonHidden()
//                    .primaryBackground()
////                    .safeAreaPadding(.bottom, 32 + safeAreaInsets.bottom)
//                }
//        }
//    }
//}
//
//#Preview {
//    CliqueCreatorFlow()
//}
