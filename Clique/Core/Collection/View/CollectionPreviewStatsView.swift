//
//  CollectionPreviewStatsView.swift
//  Clique
//
//  Created by Rod Tavangar on 12/11/24.
//

import SwiftUI

struct CollectionPreviewStatsView: View {
    let likes: Int
    let comments: Int
    let hasLiked: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                IconImage("heart-filled", color: hasLiked ? .theme.red : .theme.white, size: 12)
                
                Text(formatNumber(likes))
                    .font(.caption2.bold())
                    .foregroundStyle(Color.theme.white)
            }
            
            HStack(spacing: 4) {
                IconImage("comment-filled", color: .theme.white, size: 12)
                
                Text(formatNumber(comments))
                    .font(.caption2.bold())
                    .foregroundStyle(Color.theme.white)
            }
        }
//        .frame(maxWidth: .infinity, alignment: .leading)
//        .frame(maxHeight: .infinity, alignment: .bottom)
        .padding(.leading, 4)
        .padding(.bottom, 3)
        .maxWidth(.leading)
        .background(Gradients.feedCellCommentBg)
//        .shadow(color: .black.opacity(0.8), radius: 7.5)
    }
}

#Preview {
    Rectangle()
        .fill(.blue)
        .frame(100)
        .overlay(alignment: .bottomLeading) {
            CollectionPreviewStatsView(likes: 2, comments: 20, hasLiked: false)
        }
}
