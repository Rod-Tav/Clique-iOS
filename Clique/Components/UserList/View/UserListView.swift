////
////  UserListView.swift
////  Clique
////
////  Created by Rod Tavangar on 6/10/24.
////
//
//import SwiftUI
//
//
//// TODO: deprecate
//struct UserListView: View {
//    @StateObject var viewModel = UserListViewModel()
//    
//    @State private var following: Bool = false
//    @Binding var searching: Bool
//    
//    let config: UserListConfig
//    var searchText: String = ""
//    var cellType: UserListCellViewType = .search
//    
//    let users: [User]
//    
//    init(
//        config: UserListConfig,
//        searchText: String = "",
//        cellType: UserListCellViewType = .search,
//        users: [User],
//        searching: Binding<Bool> = .constant(false) // Default to a non-reactive constant
//    ) {
//        self.config = config
//        self.searchText = searchText
//        self.cellType = cellType
//        self.users = users
//        self._searching = searching // Note: `_searching` because it's a @Binding
//    }
//    
//    var body: some View {
//        if searching {
//            CliqueProgressView()
//                .scaleEffect(2.0, anchor: .center)
//        } else {
//            ScrollView {
//                LazyVStack(alignment: .leading, spacing: 12) {
//                    ForEach(users) { user in
//                        NavigationLink(value: user) {
//                            HStack(spacing: 0) {
//                                UserListCellView(user: user, type: cellType)
//                                
//                                if cellType == .search {
//                                    Spacer()
//                                    
//                                    AddFollowButton()
//                                }
//                            }
//                            .contentShape(.rect)
//                        }.buttonStyle(.noHighlight)
//                    }
//                }
//            }
//        }
//    }
//    
//    @ViewBuilder
//    private func AddFollowButton() -> some View {
//        if following { // fetch if user is following
//            SmallCTA(type: .secondary, leadingIcon: "check", text: "Friends") {
//                following.toggle()
//            }
//        } else {
//            SmallCTA(type: .primary, leadingIcon: "plus", text: "Add") {
//                following.toggle()
//            }
//        }
//    }
//}
//
//#Preview {
//    UserListView(config: .search, searchText: "", users: User.MOCK_USERS)
//}
