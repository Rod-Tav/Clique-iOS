////
////  DetailBackground.swift
////  Clique
////
////  Created by Rod Tavangar on 10/23/24.
////
//
//import SwiftUI
//import LazyPager
//
//struct DetailBackground: View {
//    @Environment(UICoordinator.self) private var coordinator
//    @Environment(TabViewCoordinator.self) private var tabCoordinator
//    
//    @State var opacity: CGFloat = 1
//    @State var index = 0
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 0) {
//            LazyPager(data: coordinator.items, page: $index) { element in
//                Image(element.imageUrl ?? "")
//                    .resizable()
//                    .scaledToFit()
//                    .contentShape(.rect)
//                    .offset(y: -32)
////                    .onTapGesture {
////                        coordinator.showDetailBars.toggle()
////                    }
//            }
//            .zoomable(min: 1, max: 5, doubleTapGesture: DoubleTap.scale(0.5))
//            .onDismiss(backgroundOpacity: $opacity) {
//                withAnimation(.easeInOut(duration: 0.3)) {
//                    tabCoordinator.showTabBar = true
//                }
//                coordinator.showDetailView = false
//                coordinator.hideDetailBars = true
//                coordinator.animateView = false
//                coordinator.offset = .zero
//                coordinator.resetAnimationProperties()
//            }
//            .background(ClearFullScreenBackground())
//            .opacity(coordinator.showDetailView ? 1 : 0)
////            .onTapGesture {
////                coordinator.showDetailBars.toggle()
////            }
//            .onChange(of: coordinator.viewItemPosition ?? 0, { oldValue, newValue in
//                index = newValue
//            })
//            .onChange(of: index, { oldValue, newValue in
//                coordinator.viewItemPosition = newValue
//                coordinator.didDetailPageChanged()
//            })
//            .onChange(of: opacity, { oldValue, newValue in
//                coordinator.opacity = newValue
//            })
//            .background {
//                if let selectedItem = coordinator.viewItem {
//                    Rectangle()
//                        .fill(.clear)
//                        .anchorPreference(key: HeroKey.self, value: .bounds, transform: { anchor in
//                            return [selectedItem.id + "DEST": anchor]
//                        })
//                }
//            }
////            .offset(coordinator.offset)
////            .offset(y: -32)
////            .safeAreaPadding(.bottom)
//        }
//        .onAppear {
//            if let viewItemPosition = coordinator.viewItemPosition {
//                index = viewItemPosition
//            }
//        }
//    }
//}
//
//#Preview {
//    DetailBackground()
//}
