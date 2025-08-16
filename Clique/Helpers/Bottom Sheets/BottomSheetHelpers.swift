//
//  BottomSheetHelpers.swift
//  Clique
//
//  Created by Rod Tavangar on 1/30/25.
//

import SwiftUI

//// MARK: - Standard bottom sheet
//extension View {
//    func bottomSheet<Content: View>(
//        isPresented: Binding<Bool>,
//        @ViewBuilder content: @escaping () -> Content
//    ) -> some View {
//        self.modifier(StandardBottomSheetModifier(isPresented: isPresented, sheetContent: content))
//    }
//}
//
//private struct StandardBottomSheetModifier<SheetContent: View>: ViewModifier {
//    @Binding var isPresented: Bool
//    let sheetContent: () -> SheetContent
//    
//    func body(content: Content) -> some View {
//        content
//            .sheet(isPresented: $isPresented) {
//                sheetContent()
//                    .presentationDetents([.fraction(0.44), .fraction(0.999)])
//                    .bottomSheetModifiers()
//            }
//    }
//}

// MARK: - Bottom sheet over tab bar
extension View {
//    func tabSheet<SheetContent: View>(
//        initialHeight: CGFloat = (UIScreen.height - Constants.bottomTabBarHeight) / 2,
//        isPresented: Binding<Bool>,
//        sheetCornerRadius: CGFloat = 24,
//        @ViewBuilder content: @escaping () -> SheetContent
//    ) -> some View {
//        self
//            .modifier(BottomSheetOverTabBarModifier(
//                isPresented: isPresented,
//                initialHeight: initialHeight,
//                sheetCornerRadius: sheetCornerRadius,
//                sheetView: content
//            ))
//    }
}

private struct BottomSheetOverTabBarModifier<SheetContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    var initialHeight: CGFloat
    var sheetCornerRadius: CGFloat
    let sheetView: () -> SheetContent
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented, content: {
                VStack(spacing: 0) {
                    sheetView()
                        .presentationDetents([.fraction(0.44), .fraction(0.999)])
                        .zIndex(0)
                        .background(.red)
                    
                    Divider()
                        .hidden()
                    
                    Rectangle()
                        .fill(.clear)
                        .frame(height: Constants.bottomTabBarHeight)
                }
                
                .presentationDetents([.height(initialHeight), .medium, .fraction(0.99)])
                .presentationCornerRadius(sheetCornerRadius)
//                .presentationBackgroundInteraction(.enabled(upThrough:.medium))
                .presentationBackground(.clear)
//                .interactiveDismissDisabled()
//                .bottomSheetModifiers()
            })
        
    }
}
