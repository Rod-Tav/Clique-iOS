////
////  CollectionView.swift
////  Clique
////
////  Created by Rod Tavangar on 7/16/24.
////
//
//import SwiftUI
//import ScalingHeaderScrollView
//import PopupView
//
//struct CollectionView: View {
//    @Environment(UICoordinator.self) private var coordinator
//    @Environment(\.dismiss) var dismiss
//    @Environment(TabViewCoordinator.self) private var tabCoordinator
//    @ObservedObject var viewModel: OldCollectionViewModel
//    
////    @State private var headerHeight: CGFloat = 0
//    @State var progress: CGFloat = 0
//    
//    private var clique: Clique {
//        viewModel.fetchClique()
//    }
//    
//    private var cliqueMembers: [User] {
//        viewModel.fetchCliqueMembers(cid: clique.id)
//    }
//    
//    let collection: ClCollection
//    
//    private var coverPhotoGradient: LinearGradient {
//        LinearGradient(
//            stops: [
//                Gradient.Stop(color: .black.opacity(0.8), location: 0.00),
//                Gradient.Stop(color: .black.opacity(0.7), location: 0.28),
//                Gradient.Stop(color: .black.opacity(0), location: 0.56),
//            ],
//            startPoint: UnitPoint(x: 0.5, y: 0),
//            endPoint: UnitPoint(x: 0.5, y: 1)
//        )
//    }
//    
//    init(collection: ClCollection) {
//        self.collection = collection
//        self.viewModel = OldCollectionViewModel(collection: collection)
//    }
//    
//    var body: some View {
//        @Bindable var bindableCoordinator = coordinator
//        GeometryReader {
//            let width = $0.size.width
//            let previewHeight = (width - 4.0) / 3 / Constants.collectionPreviewRatio
//            
//            ScrollViewReader { reader in
//                ScalingHeaderScrollView {
//                    CollectionHeader()
//                } content: {
//                    VStack(spacing: 16) {
//                        LazyVGrid(columns: Array(repeating: GridItem(spacing: 2), count: 3), spacing: 2) {
//                            ForEach($bindableCoordinator.items) { $item in
//                                CollectionImageView(item)
//                                    .frame(height: abs(previewHeight))
//                                    .id(item.id)
//                                    .didFrameChange { frame, bounds in
//                                        let minY = frame.minY
//                                        let maxY = frame.maxY
//                                        let height = bounds.height
//                                        
//                                        if maxY < 0 || minY > height {
//                                            item.appeared = false
//                                        } else {
//                                            item.appeared = true
//                                        }
//                                    }
//                                    .onDisappear {
//                                        item.appeared = false
//                                    }
//                                    .onTapGesture {
//                                        if coordinator.canTap {
//                                            withAnimation(.easeInOut(duration: 0.4)) {
//                                                tabCoordinator.showTabBar = false
//                                                coordinator.opacity = 1
//                                            }
//                                            withAnimation(.easeInOut(duration: 0.25)) {
//                                                if coordinator.viewItem == nil {
//                                                    coordinator.viewItem = item
//                                                    coordinator.viewItemPosition = item.index
//                                                    
//                                                }
//                                            }
//                                        }
//                                    }
//                            }
//                        }
//                    }
//                }
////                .allowsHeaderGrowth()
//                .collapseProgress($progress)
//                .height(min: viewModel.minHeight, max: viewModel.maxHeight)
//                .setHeaderSnapMode(.afterFinishAccelerating)
//                .ignoresSafeArea()
//                .onChange(of: coordinator.viewItem) { oldValue, newValue in
//                    if let item = coordinator.items.first(where: { $0.id == newValue?.id }), !item.appeared {
//                        /// Scroll to this item, as this is not visible on the screen
//                        reader.scrollTo(item.id, anchor: .bottom)
//                    }
//                }
//            }
//            .toolbar { // hack to get rid of preference key error
//                ToolbarItem(placement: .topBarLeading) {
//                    Image(systemName: "chevron.left")
//                }
//            }
//            .toolbar(.hidden, for: .navigationBar) // hack as part of above
//        }
//        .primaryBackground()
//        .sheet(isPresented: $showCliqueMembers) {
//            CliqueMembersListView(clique: collection.clique)
//                .presentationDragIndicator(.visible)
//                .presentationDetents([.fraction(0.999)])
//        }
//    }
//    
//    @ViewBuilder
//    private func CollectionHeader() -> some View {
//        ZStack {
//            CollectionExpandedHeader()
//                .opacity(1 - max(0, min(1, (progress - 0.75) * 4.0)))
//            
//            CollectionCollapsedHeader()
//                .opacity(max(0, min(1, (progress - 0.75) * 4.0)))
//        }
//    }
//    
//    @ViewBuilder
//    private func CollectionCollapsedHeader() -> some View {
//        VStack(spacing: 0) {
//            Spacer()
//            
//            VStack(spacing: 0) {
//                ZStack(alignment: .bottom) {
//                    Image(collection.coverPhoto)
//                        .resizable()
//                        .scaledToFill()
//                        .frame(height: viewModel.minHeight)
//                        .overlay(Color.theme.black.opacity(0.5))
//                        .clipped()
//                        .blur(radius: 5, opaque: true)
//                    
//                    HStack(spacing: 0) {
//                        Button {
//                            dismiss()
//                        } label: {
//                            Image("arrow-left")
//                                .iconButton(color: Color.theme.white, size: 16)
//                        }
//                        
//                        Spacer()
//                        
//                        Text(collection.name)
//                            .font(.body.bold())
//                            .foregroundStyle(Color.theme.white)
//                        
//                        Spacer()
//                        
//                        Button {
//                            
//                        } label: {
//                            Image("ellipsis")
//                                .iconButton(color: Color.theme.white, size: 20)
//                        }
//                    }
//                    .padding(.horizontal, 24)
//                    .padding(.bottom, 16)
//                }
//            }
//            .background(
//                GeometryReader { contentGeo in
//                    Color.clear
//                        .onAppear {
//                            viewModel.minHeight = contentGeo.size.height
////                                                        print("Content height:", viewModel.minHeight)
//                        }
//                }
//            )
//        }
//    }
//    
//    @State private var showCliqueMembers: Bool = false
//    
//    @ViewBuilder
//    private func CollectionExpandedHeader() -> some View {
//        VStack(alignment: .leading, spacing: 0) {
//            VStack(alignment: .leading, spacing: 0) {
//                ZStack(alignment: .top) {
//                    Image(collection.coverPhoto)
//                        .collectionCoverPreviewModifiers()
//                        .overlay(coverPhotoGradient)
//                    
//                    TopBar()
//                }
//                
//                HStack(spacing: 0) {
//                    CliquePfpView(pfp: clique.cliquePic, type: .collection)
//                    
//                    Spacer()
//                    
//                    Button {
//                        showCliqueMembers = true
//                    } label: {
//                        CliqueCircularMembersView(members: cliqueMembers, memberCount: cliqueMembers.count, type: .collection)
//                    }.buttonStyle(.noHighlight)
//                }
//                .padding(.horizontal, 24)
//                .padding(.top, -ProfileImageSize.small.dimension / 2)
//                .padding(.bottom, 12)
//            }
//            
//            CollectionInfo()
//                .padding(.bottom, 24)
//        }
//        .background(
//            GeometryReader { contentGeo in
//                Color.clear
//                    .onAppear {
//                        viewModel.maxHeight = contentGeo.size.height
////                        print("Max height:", viewModel.maxHeight, contentGeo.size)
//                    }
//            }
//        )
//        .onChange(of: tabCoordinator.sameTabTapped) {
//            if tabCoordinator.sameTabTapped {
//                dismiss()
//            }
//        }
//    }
//    
//    private func formattedDate(_ date: Date) -> String {
//        let dateFormatter = DateFormatter()
//        dateFormatter.dateFormat = "MMMM dd, yyyy"
//        return dateFormatter.string(from: date)
//    }
//    
//    @ViewBuilder
//    private func TopBar() -> some View {
//        VStack {
//            HStack {
//                Button {
//                    dismiss()
//                } label: {
//                    Image("arrow-left")
//                        .iconButton(color: Color.theme.white, size: 16)
//                }
//                
//                Spacer()
//                
//                Button {
//                    // open more
//                    // TODO: functionality/design
//                } label: {
//                    Image("ellipsis")
//                        .iconButton(color: Color.theme.white, size: 20)
//                }
//            }
//            .padding(.horizontal, 16)
//        }
//        .safeAreaPadding(.top, 62)
//    }
//    
//    @ViewBuilder
//    private func CollectionInfo() -> some View {
//        VStack(alignment: .leading, spacing: 12) {
//            VStack(alignment: .leading, spacing: 4) {
//                Text(collection.name)
//                    .font(.title3.bold())
//                
//                CollectionDateAndFlicks()
//            }
//            
//            if let caption = collection.caption {
//                Text(caption)
//                    .font(.caption)
//            }
//        }
//        .padding(.horizontal, 24)
//    }
//    
//    @ViewBuilder
//    private func CollectionDateAndFlicks() -> some View {
//        HStack(spacing: 2) {
//            HStack(spacing: 4) {
//                Image("calendar")
//                    .icon(color: Color.theme.iconSecondary, size: 16)
//                
//                Text(formattedDate(collection.creation))
//                    .font(.caption)
//                    .secondaryStyle()
//            }
//            
//            Text("• \(collection.images.count) Flicks")
//                .font(.caption)
//                .secondaryStyle()
//        }
//    }
//    
//    @ViewBuilder
//    func CollectionImageView(_ item: CollectionImage) -> some View {
//        GeometryReader {
//            let size = $0.size
//            
//            Group {
//                Rectangle()
//                    .fill(.clear)
//                    .anchorPreference(key: HeroKey.self, value: .bounds, transform: { anchor in
//                        return [item.id + "SOURCE": anchor]
//                    })
//                
//                if let previewImage = item.previewImageUrl {
//                    Image(previewImage)
//                        .resizable()
//                        .scaledToFill()
//                        .frame(width: size.width, height: size.width / Constants.collectionPreviewRatio)
//                        .clipped()
//                    //                    .opacity(coordinator.viewItem?.id == item.id ? 0 : 1)
//                }
//            }
//            .overlay(CollectionPreviewStatsView(image: item))
//        }
////        .frame(height: (UIScreen.main.bounds.width - 32) / 3 / Constants.collectionPreviewRatio)
//        .contentShape(.rect)
//    }
//}
//
//#Preview {
//    CollectionView(collection: ClCollection.MOCK_COLLECTIONS[0])
//        .environment(TabViewCoordinator())
//        .environment(UICoordinator(collection: ClCollection.MOCK_COLLECTIONS[0]))
//}
