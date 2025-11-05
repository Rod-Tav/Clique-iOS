//
//  LivePhotoBadge.swift
//  Clique
//
//  Created by Assistant on Live Photo indicator implementation.
//

import SwiftUI

/// Badge overlay indicating a Live Photo.
///
/// Displays a small badge with the SF Symbol "livephoto" to indicate
/// that the image is a Live Photo with video component.
///
/// ## Usage
/// ```swift
/// Image("photo")
///     .overlay(alignment: .topLeading) {
///         LivePhotoBadge()
///     }
/// ```
struct LivePhotoBadge: View {
    var showText: Bool = true
    
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "livephoto")
                .font(.system(size: 8, weight: .semibold))

            if showText {
                Text("LIVE")
                    .font(.system(size: 10, weight: .semibold))
            }
        }
        .foregroundStyle(.yellow)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color(.systemGray5))
        .clipShape(.capsule)
        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    ZStack {
        Rectangle()
            .fill(.gray)
            .frame(width: 200, height: 200)

        LivePhotoBadge()
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
