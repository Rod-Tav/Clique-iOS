//
//  CreateFlowWrapper.swift
//  Clique
//
//  Created by Rod Tavangar on 8/1/25.
//

import SwiftUI

struct CreateFlowWrapper: View {
    @Environment(TabViewCoordinator.self) private var tabViewCoordinator
    
    @State private var viewModel = CreateViewModel()
    
    var body: some View {
        Group {
            switch tabViewCoordinator.createFlowMode {
            case .none:
                // Show nothing until user selects camera or library from menu
                // This prevents eager camera initialization
                Color.clear
            case .camera:
                CameraCreateFlow()
                    .environment(viewModel)
            case .library:
                LibraryCreateFlow()
                    .environment(viewModel)
            }
        }
    }
}
