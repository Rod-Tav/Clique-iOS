//
//  TopIconBar.swift
//  Clique
//
//  Created by Rod Tavangar on 1/16/25.
//

import SwiftUI

struct TopIconBar: View {
    @Environment(TopIconFlowCoordinator.self) private var coordinator
    let icons: [String]
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<icons.count, id: \.self) { index in
                HStack(spacing: 8) {
                    IconImage(icons[index], color: .theme.shadesWhite95, size: 12)
                }
                .frame(24)
                .background(index+1 <= coordinator.currentIconStep ? coordinator.iconBgColor : Color.theme.surfacesElevatedPrimary)
                .clipShape(.circle)
                
                if index < icons.count - 1 {
                    Rectangle()
                        .foregroundColor(.clear)
                        .frame(width: 32, height: 4)
                        .background(
                            (coordinator.highlightNextBar ? index <= coordinator.currentIconStep-1 : index < coordinator.currentIconStep-1)
                            ? coordinator.iconBgColor
                            : Color.theme.surfacesElevatedPrimary
                        )
                        .roundCorners(8)
                        .animation(.easeInOut, value: coordinator.highlightNextBar)
                }
            }
        }
        .animation(.easeInOut, value: coordinator.currentIconStep)
    }
}

#Preview {
    TopIconBar(icons: ["2-user", "pen", "camera"])
        .environment(TopIconFlowCoordinator())
}
