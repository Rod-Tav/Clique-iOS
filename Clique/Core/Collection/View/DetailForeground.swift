////
////  DetailForeground.swift
////  Clique
////
////  Created by Rod Tavangar on 10/23/24.
////
//
//import SwiftUI
//
//struct DetailForeground: View {
//    @Environment(UICoordinator.self) private var coordinator
//    @Environment(TabViewCoordinator.self) private var tabCoordinator
//    
//    var body: some View {
//        VStack(spacing: 0) {
//            NavigationBar()
//            
//            Spacer()
//            
//            VStack(spacing: 0) {
//                BottomIndicatorView()
//                    .padding(.vertical, 24)
//                
//                BottomActionBar()
//            }
//        }
//        .onAppear {
//            coordinator.toggleView(show: true)
//        }
//    }
//    
//    /// Custom Navigation Bar
//    @ViewBuilder
//    private func NavigationBar() -> some View {
//        HStack(spacing: 0) {
//            Button {
//                tabCoordinator.showTabBar = true
//                coordinator.toggleView(show: false)
//            } label: {
//                Image("x-icon")
//                    .resizable()
//                    .frame(width: 24, height: 24)
//            }
//            
//            Spacer()
//            
//            if let date = coordinator.viewItem?.date {
//                VStack {
//                    Text(coordinator.collection.name)
//                        .font(.body.bold())
//                        .foregroundStyle(.white)
//                    
//                    Text(formatDate(date))
//                        .font(.caption)
//                        .foregroundStyle(.white)
//                }
//            }
//            
//            Spacer()
//            
//            //            if let imageUrl = coordinator.viewItem?.imageUrl {
//            //                ShareLink(item: Image(imageUrl), preview: SharePreview("Share image", image: Image(imageUrl))) {
//            //                    Image(systemName: "square.and.arrow.up")
//            //                        .imageScale(.large)
//            //                        .foregroundStyle(Color.primary)
//            //                }
//            //            }
//            
//            Button {
//                
//            } label: {
//                Image("ellipsis")
//                    .resizable()
//                    .frame(width: 20, height: 20)
//            }
//        }
//        .padding(.bottom, 8)
//        .padding(.horizontal, 16)
//        //        .offset(y: coordinator.showDetailBars ? (-110 * coordinator.dragProgress) : -110)
//        //        .animation(.easeInOut(duration: 0.3), value: coordinator.showDetailBars)
//        .opacity(coordinator.showDetailBars && !coordinator.hideDetailBars ? 1 - coordinator.dragProgress : 0)
//        .animation(.easeInOut(duration: 0.2), value: coordinator.showDetailBars)
//        .animation(.easeInOut(duration: 0.2), value: coordinator.hideDetailBars)
//        .opacity(coordinator.opacity)
//    }
//    
//    private func formatDate(_ date: Date) -> String {
//        let dateFormatter = DateFormatter()
//        dateFormatter.dateFormat = "M/d/yyyy"
//        return dateFormatter.string(from: date)
//    }
//    
//    /// Bottom Indicator View
//    @ViewBuilder
//    private func BottomIndicatorView() -> some View {
//        GeometryReader {
//            let size = $0.size
//            
//            ScrollView(.horizontal) {
//                LazyHStack(spacing: 4) {
//                    ForEach(coordinator.items) { item in
//                        /// Preview Image View
//                        if let image = item.previewImageUrl {
//                            let selected = image == coordinator.viewItem?.previewImageUrl
//                            Image(image)
//                                .resizable()
//                                .aspectRatio(contentMode: .fill)
//                                .frame(width: selected ? 56 : 35, height: selected ? 68 : 52)
//                                .clipShape(RoundedRectangle(cornerRadius: 8))
//                                .animation(.snappy, value: selected)
//                            //                                .scaleEffect(0.97)
////                                .clipped()
//                        }
//                    }
//                }
////                .padding(.vertical, 10)
//                .scrollTargetLayout()
//            }
//            /// 35 - Item Size Inside ScrollView
//            .safeAreaPadding(.horizontal, (size.width - 56) / 2)
//            //            .overlay {
//            //                /// Active Indicator Icon
//            //                Rectangle()
//            //                    .stroke(Color.primary.opacity(0.9), lineWidth: 2)
//            //                    .frame(width: 30, height: size.height)
//            //                    .allowsHitTesting(false)
//            //            }
//            .scrollTargetBehavior(.viewAligned)
//            .scrollPosition(id: .init(get: {
//                return coordinator.detailIndicatorPosition
//            }, set: {
//                coordinator.detailIndicatorPosition = $0
//            }))
//            .scrollIndicators(.hidden)
//            .onChange(of: coordinator.detailIndicatorPosition) { oldValue, newValue in
//                coordinator.didDetailIndicatorPageChanged()
//            }
//            .opacity(coordinator.opacity)
//        }
//        .frame(height: 68)
//        //        .offset(y: coordinator.showDetailBars ? (70 * coordinator.dragProgress) : 70)
//        .clipShape(Rectangle().offset(y: coordinator.showDetailBars && !coordinator.hideDetailBars ? coordinator.dragProgress * 50 : 40))
//        .opacity(coordinator.showDetailBars && !coordinator.hideDetailBars ? 1 - coordinator.dragProgress : 0)
//        .animation(.easeInOut(duration: 0.2), value: coordinator.showDetailBars)
//        .animation(.easeInOut(duration: 0.2), value: coordinator.hideDetailBars)
//        //        .transition(.opacity)
//    }
//    
//    /// Bottom Action Bar
//    @ViewBuilder
//    private func BottomActionBar() -> some View {
//        HStack(spacing: 16) {
//            Image("comment_stroke")
//                .resizable()
//                .frame(width: 20, height: 20)
//                .foregroundStyle(.white)
//            
//            HStack(spacing: 8) {
//                Text("Add a comment...")
//                    .font(.footnote)
//                    .foregroundColor(.white.opacity(0.9))
//            }
//            .padding(.horizontal, 16)
//            .padding(.vertical, 8)
//            .frame(maxWidth: .infinity, alignment: .leading)
//            .background(.black.opacity(0.5))
//            .cornerRadius(16)
//            .overlay(
//                RoundedRectangle(cornerRadius: 16)
//                    .inset(by: -0.5)
//                    .stroke(.white.opacity(0.5), lineWidth: 1)
//            )
//            
//            HStack(alignment: .center, spacing: 4) {
//                Image("user_icon")
//                    .frame(width: 24, height: 24)
//                
//                Text("\(coordinator.viewItem?.taggedMembers ?? 0)")
//                    .font(.footnote.bold())
//                    .foregroundColor(.white)
//            }
//            .padding(0)
//            
//            HStack(spacing: 8) {
//                Image("heart_stroke")
//                    .resizable()
//                    .frame(width: 20, height: 18.99996)
//                    .foregroundStyle(.white)
//                
//                Text(formatNumber(coordinator.viewItem?.likes ?? 0))
//                    .font(.footnote.bold())
//                    .foregroundStyle(.white)
//            }
//            .padding(0)
//        }
//        .padding(.horizontal, 24)
//        .padding(.vertical, 8)
//        .opacity(coordinator.opacity)
//    }
//}
//
//#Preview {
//    DetailForeground()
//}
