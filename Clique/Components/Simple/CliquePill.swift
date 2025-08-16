//
//  CliquePill.swift
//  Clique
//
//  Created by Rod Tavangar on 1/9/25.
//

import SwiftUI

enum CliquePillType {
    case collectionPreview
    case cliqueProfile
    case feedCell
    case newCollection
    case imagePreview
    case createCollections
    
    var background: Color {
        switch self {
        case .collectionPreview:
            return .theme.strokeBgMatch
        case .cliqueProfile:
            return .theme.shadesWhite15
        case .feedCell, .createCollections:
            return .theme.surfacesElevatedPrimary
        case .newCollection:
            return .theme.surfacesPrimary
        case .imagePreview:
            return .theme.surfacesElevatedBlur
        }
    }
    
    var pfpType: CliquePfpViewType {
        switch self {
        case .collectionPreview:
            return .collectionPreview
        case .cliqueProfile:
            return .xSmall
        case .feedCell, .newCollection, .createCollections: // TODO: create should be size 24 but lazy
            return .feedCell
        case .imagePreview:
            return .postDetails // TODO: lazy
        }
    }
    
    var font: Font {
        switch self {
        case .collectionPreview, .imagePreview:
            return .caption.bold()
        case .cliqueProfile:
            return .footnote
        case .feedCell, .newCollection, .createCollections:
            return .caption2.weight(.semibold)
        }
    }
    
    var textColor: Color {
        switch self {
        case .collectionPreview:
            return .theme.textSecondary // not used
        case .cliqueProfile:
            return .theme.white
        case .feedCell, .newCollection, .createCollections:
            return .theme.textPrimary
        case .imagePreview:
            return .theme.shadesWhite95
        }
    }
}

struct CliquePill: View {
    @Environment(CliqueStore.self) private var cliqueStore
    
    let cid: String
    let type: CliquePillType
    var spacing: CGFloat? = 12
    
    private var clique: Clique? {
        cliqueStore.cliques[cid]
    }
    
    init(_ cid: String, type: CliquePillType, spacing: CGFloat? = 12) {
        self.cid = cid
        self.type = type
        self.spacing = spacing
    }
    
    var body: some View {
        if let clique {
            if type == .collectionPreview {
                CliquePfpAsyncView(pfp: clique.cliquePic, type: type.pfpType, hasBorder: true, quality: .low)
            } else {
                HStack(spacing: spacing) {
                    CliquePfpAsyncView(pfp: clique.cliquePic, type: type.pfpType, hasBorder: false, quality: .low)
                    
                    Text(clique.name)
                        .font(type.font)
                        .foregroundStyle(type.textColor)
                }
                .padding(.trailing, spacing)
                .background(type.background.blur(radius: type == .newCollection ? 0 : 12.5)) // opaque blur doesn't work
                .roundCorners(8)
            }
        }
    }
}

#Preview {
    CliquePill(Clique.MOCK_CLIQUES[0].id, type: .feedCell)
}
