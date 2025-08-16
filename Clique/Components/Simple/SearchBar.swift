//
//  SearchBar.swift
//  Clique
//
//  Created by Rod Tavangar on 12/5/24.
//

import SwiftUI

struct SearchBar: View {
    @Binding var searchText: String
    @FocusState.Binding var isSearchFocused: Bool
    
    var buttonText: String = "Cancel"
    var disableAutocorrect: Bool = false
    
    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                IconImage("search", color: .theme.textSecondary, size: 20)
                
                TextField(
                    "",
                    text: $searchText,
                    prompt: Text("Search...").foregroundStyle(Color.theme.textSecondary)
                )
                .font(.footnote)
                .autocorrectionDisabled(disableAutocorrect)
                .focused($isSearchFocused)
                .submitLabel(.search)
//                .if(disableAutocorrect) { view in
//                    view
//                        .keyboardType(.asciiCapable)
//                }
                
                if isSearchFocused {
//                    Button {
//                        searchText = ""
//                    } label: {
                        IconImage("x-icon", color: .theme.iconPrimary, size: 16)
                        .contentShape(.rect)
                        .onHighPriorityTap {
                            if searchText.isEmpty {
                                isSearchFocused = false
                            } else {
                                searchText = ""
                            }
                        }
//                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding(8)
            .background(Color.theme.buttonTertiary)
            .roundCorners(8)
            
            if isSearchFocused {
                TextButton(buttonText) {
                    searchText = ""
                    isSearchFocused = false
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.bouncy(duration: 0.5), value: isSearchFocused)
    }
}

//#Preview {
//    SearchView(UserStore())
//        .environment(TabViewCoordinator())
//}
