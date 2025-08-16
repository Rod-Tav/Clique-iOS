//
//  CliquePfpView.swift
//  Clique
//
//  Created by Rod Tavangar on 6/25/24.
//

import SwiftUI

struct CliquePfpView: View {
    var pfp: Image
    var type: CliquePfpViewType
    var hasBorder: Bool = true
    
    init(pfp: String, type: CliquePfpViewType) {
        self.pfp = Image(pfp)
        self.type = type
    }
    
    init(pfp: Image, type: CliquePfpViewType) {
        self.pfp = pfp
        self.type = type
    }
    
    init(pfp: UIImage, type: CliquePfpViewType) {
        self.pfp = Image(uiImage: pfp)
        self.type = type
    }
    
    // default
    init(type: CliquePfpViewType) {
        self.pfp = Image("default-gradient")
        self.type = type
    }
    
    init(pfp: Image, type: CliquePfpViewType, hasBorder: Bool) {
        self.pfp = pfp
        self.type = type
        self.hasBorder = hasBorder
    }
    
    var body: some View {
        pfp
            .cliquePfp(type: type, hasBorder: hasBorder)
    }
}

extension Image {
    func cliquePfp(type: CliquePfpViewType, hasBorder: Bool) -> some View {
        self
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(type.size)
            .roundCorners(type.cornerRadius)
            .if(hasBorder) { view in
                view
                    .overlay {
                        RoundedRectangle(cornerRadius: type.cornerRadius)
                            .inset(by: type.inset)
                            .stroke(type.strokeColor, lineWidth: type.lineWidth)
                    }
            }
    }
}
