//
//  AuthDescription.swift
//  Clique
//
//  Created by Quinn Liu on 1/22/25.
//

import SwiftUI

struct AuthFlowDescription: View {
    @Environment(AuthFlowViewModel.self) private var viewModel
    
    var entryType: AuthEntryType
    
    var body: some View {
        switch entryType {
        case .phone:
//            HStack(spacing: 16) {
                Text(viewModel.phone.formatPhoneNumber())
                    .textSecondary()

            // lowkey they can just restart the app if they need to resend
            // firebase doesn't support it yet and bots could spam
            // so add timer later
//                TextButton("Resend") {
//                    // resend confirmation code function
//                }
//            }
        case .username:
            Text("Get creative with it...")
                .textSecondary()
                .font(.body)
        default:
            EmptyView()
        }
    }
}

//#Preview {
//    AuthDescription()
//}
