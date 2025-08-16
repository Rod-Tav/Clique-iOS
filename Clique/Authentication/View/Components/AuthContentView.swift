//
//  NewAuthenticationContentView.swift
//  Clique
//
//  Created by Quinn Liu on 1/13/25.
//

import SwiftUI

struct AuthContentView<Description: View, InputView: View>: View {
    let title: String
    @ViewBuilder var description: Description
    @ViewBuilder var inputView: InputView
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .textPrimary()
                    .kerning(0.1292)
                    .maxWidth(.leading)
                    .multilineTextAlignment(.leading)
                    .font(.largeTitle.bold())

                description
            }
            
            inputView
        }
    }
}

//#Preview {
//    NewAuthenticationContentView()
//}
