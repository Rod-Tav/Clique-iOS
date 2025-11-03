//
//  VideoBadge.swift
//  Clique
//
//  Created by Assistant on Video indicator implementation.
//

import SwiftUI

/// Badge overlay indicating a standalone video.
///
/// Displays a small badge with the SF Symbol "play.fill" to indicate
/// that the media is a standalone video (not a Live Photo).
///
/// ## Usage
/// ```swift
/// Image("thumbnail")
///     .overlay(alignment: .topLeading) {
///         VideoBadge()
///     }
/// ```
struct VideoBadge: View {
    var showText: Bool = true

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "play.fill")
                .font(.system(size: 8, weight: .semibold))

            if showText {
                Text("VIDEO")
                    .font(.system(size: 10, weight: .semibold))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color(.systemGray))
        .clipShape(.capsule)
        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    ZStack {
        Rectangle()
            .fill(.gray)
            .frame(width: 200, height: 200)

        VideoBadge()
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
