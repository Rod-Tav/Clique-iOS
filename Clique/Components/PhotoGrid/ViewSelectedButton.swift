//
//  ViewSelectedButton.swift
//  Clique
//
//  Created by Assistant on 8/29/25.
//

import SwiftUI

struct ViewSelectedButton: View {
    @Environment(CreateViewModel.self) var viewModel
    @Binding var showSelectedPhotosView: Bool
    
    var body: some View {
        if !viewModel.selectedAssets.isEmpty {
            CliqueButton(type: .primary, leadingIcon: "images-posts", text: "View Selected (\(viewModel.selectedAssets.count))", size: 20) {
                showSelectedPhotosView = true
            }
            
//            Button {
//                showSelectedPhotosView = true
//            } label: {
//                HStack(spacing: 8) {
//                    IconImage("images-posts", color: .white, size: 20)
//                    Text("View Selected (\(viewModel.selectedAssets.count))")
//                        .font(.callout.bold())
//                        .foregroundColor(.white)
//                }
//                .padding(.horizontal, 20)
//                .padding(.vertical, 12)
//                .background(Color.theme.buttonCTA)
//                .clipShape(Capsule())
//                .shadow(radius: 8, y: 4)
//            }
//            .transition(.move(edge: .bottom).combined(with: .opacity))
//            .animation(.spring(response: 0.3), value: viewModel.selectedAssets.count)
        }
    }
}
