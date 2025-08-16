////
////  CliqueCarousel.swift
////  Clique
////
////  Created by Rod Tavangar on 2/2/25.
////
//
//import SwiftUI
//
//struct CliqueCarousel: View {
//    let titleText: String
//    
//    var body: some View {
//        VStack(spacing: 0) {
//            Text(titleText)
//                .font(.footnote.bold())
//                .secondaryStyle()
//                .frame(maxWidth: .infinity, alignment: .leading)
//                .padding(.horizontal, 16)
//            
//            CliqueHubCliques()
//        }
//        .padding(.top, 12)
//        .overlay(
//            Rectangle()
//                .inset(by: 0.5)
//                .stroke(.tertiaryStroke, lineWidth: 1)
//                .frame(maxHeight: .infinity, alignment: .bottom)
//        )
//    }
//}
//
//#Preview {
//    CliqueCarousel()
//}
