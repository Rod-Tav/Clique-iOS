//
//  NothingHereYetView.swift
//  Clique
//
//  Created by Rod Tavangar on 11/18/24.
//

import SwiftUI

struct NothingHereYetSelfCliqueView: View {
    let type: CliqueProfileTab
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(type.icon)
                        .resizable()
                        .color(.black.opacity(0.5))
                        .frame(10)
                    
                    Text(type.title)
                        .font(.caption2.bold())
                        .foregroundStyle(.black.opacity(0.5))
                }
                
                Text("\(type.nothingHereString)\n\(type.callToActionString)")
                    .font(.footnote)
                    .textPrimary()
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 8) {
                Text(type.callToActionButtonTitle)
                    .font(.callout.bold())
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.theme.buttonCTA)
            .roundCorners(32)
        }
        .infiniteFrame()
    }
}

#Preview {
    NothingHereYetSelfCliqueView(type: .collections)
}
