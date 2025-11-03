//
//  CliqueCompactHeader.swift
//  Clique
//
//  Created by Rod Tavangar on 1/15/25.
//

import SwiftUI

struct CliqueCompactHeader<SubLabel: View>: View {
    @Environment(CliqueStore.self) private var cliqueStore
    
    let cid: String
    let members: [User]
    @ViewBuilder let subLabel: SubLabel
    
    private var clique: Clique? {
        cliqueStore.cliques[cid]
    }
    
    init(cid: String, members: [User], @ViewBuilder subLabel: () -> SubLabel = { EmptyView() }) {
        self.cid = cid
        self.members = members
        self.subLabel = subLabel()
    }
    
    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 12) {
                CliquePill(cid: cid, type: .feedCell)
                
                //                    VStack(alignment: .leading, spacing: 0) {
                //                        subLabel
                //
                //                        Text(clique.name)
                //                            .font(.footnote.bold())
                //                            .foregroundStyle(.primaryText)
                //                    }
            }
            
            Spacer()
            
            CliqueCircularMembersView(members: members, memberLimit: 5, type: .medium)
        }
        .contentShape(.rect)
    }
}
