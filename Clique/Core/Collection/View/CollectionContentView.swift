////
////  CollectionContentView.swift
////  Clique
////
////  Created by Rod Tavangar on 7/17/24.
////
//
//import SwiftUI
//
//struct CollectionContentView: View {
//    var coordinator: UICoordinator
//    let collection: ClCollection
//    
//    init(collection: ClCollection) {
//        self.coordinator = .init(collection: collection)
//        self.collection = collection
//    }
//    
//    var body: some View {
//        CollectionView(collection: collection)
//            .environment(coordinator)
//            .allowsHitTesting(coordinator.viewItem == nil)
//            .overlay {
//                if let image = coordinator.viewItem?.imageUrl {
//                    /// background blurred image
//                    ZStack {
//                        Image(image)
//                            .resizable()
//                            .ignoresSafeArea()
//                            .scaledToFill()
//                            .blur(radius: 12.5, opaque: true)
//                        
//                        Rectangle()
//                          .foregroundColor(.clear)
//                          .frame(maxWidth: .infinity, maxHeight: .infinity)
//                          .background(.black.opacity(0.4))
//                    }
//                    .opacity(coordinator.opacity)
////                    .transition(.opacity)
////                    .animation(.easeInOut, value: coordinator.viewItem?.imageUrl)
//                }
//            }
//            .overlay {
//                if coordinator.viewItem != nil {
//                    DetailBackground()
////                        .enableFullSwipePop(!coordinator.showDetailView)
//                        .environment(coordinator)
//                        .allowsHitTesting(coordinator.showDetailView)
//                        .ignoresSafeArea()
//                }
//            }
//            .overlay {
//                if coordinator.viewItem != nil {
//                    DetailForeground()
//                        .environment(coordinator)
//                        .allowsHitTesting(coordinator.showDetailView)
//                }
//            }
//            .overlayPreferenceValue(HeroKey.self) { value in
//                if let selectedItem = coordinator.viewItem,
//                   let sAnchor = value[selectedItem.id + "SOURCE"],
//                   let dAnchor = value[selectedItem.id + "DEST"] {
//                    HeroLayer(
//                        item: selectedItem,
//                        sAnchor: sAnchor,
//                        dAnchor: dAnchor
//                    )
//                    .environment(coordinator)
//                }
//            }
//    }
//}
//
//#Preview {
//    @Previewable @Namespace var namespace
//    var coordinator: UICoordinator = .init(collection: ClCollection.MOCK_COLLECTIONS[0])
//    
//    CollectionContentView(collection: ClCollection.MOCK_COLLECTIONS[0])
//        .environment(coordinator)
//}
