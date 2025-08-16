//
//  TabsWithIndicatorBar.swift
//  Clique
//
//  Created by Rod Tavangar on 2/7/25.
//

import SwiftUI

struct TabsWithIndicatorBar<Tabs: View>: View {
    let tabCount: Int
    let alignment: Alignment
    var barWidth: CGFloat?
    @Binding var tabProgress: CGFloat
    @ViewBuilder var tabs: Tabs
    
    var body: some View {
        ZStack(alignment: alignment) {
            HStack(spacing: 0) {
                tabs
            }
            
            Divider()
                .overlay {
                    GeometryReader { geo in
                        let tabWidth = geo.size.width / CGFloat(tabCount)
                        HStack {
                            RoundedRectangle(cornerRadius: 10)
                                .foregroundStyle(Color.theme.strokePrimary)
                                .frame(width: barWidth ?? tabWidth)
                            //                        .onAppear { // hack since indicator doesn't show when first page in navstack
                            //                            if selectedFilter == 0 {
                            //                                tabProgress = 0
                            //                            }
                            //                        }
                                .offset(y: -Constants.tabBarIndicatorHeight / 2.0)
                        }
                        .frame(width: tabWidth, height: Constants.tabBarIndicatorHeight)
                        .offset(x: tabProgress * (geo.size.width))
                    }
                }
        }
    }
}

struct TextTab: View {
    let text: String
    let isSelected: Bool
    let selectedColor: Color
    let unselectedColor: Color
    let includeHaptics: Bool
    let animateSelection: Bool
    let action: () -> Void
    
    init(
        _ text: String,
        isSelected: Bool,
        selectedColor: Color = Color.theme.textPrimary,
        unselectedColor: Color = Color.theme.textSecondary,
        includeHaptics: Bool = true,
        animateSelection: Bool = true,
        action: @escaping () -> Void
    ) {
        self.text = text
        self.isSelected = isSelected
        self.selectedColor = selectedColor
        self.unselectedColor = unselectedColor
        self.includeHaptics = includeHaptics
        self.animateSelection = animateSelection
        self.action = action
    }
    
    var body: some View {
        Text(text)
            .font(.caption2.bold())
            .maxWidth()
            .padding(.vertical, 17.5)
            .contentShape(.rect)
            .foregroundStyle(isSelected ? selectedColor : unselectedColor)
            .onTapGesture {
                if includeHaptics {
                    haptics(.light)
                }
                if animateSelection {
                    withAnimation(.spring) {
                        action()
                    }
                } else {
                    action()
                }
            }
    }
}
