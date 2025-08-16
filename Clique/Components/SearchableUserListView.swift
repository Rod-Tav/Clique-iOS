////
////  SearchableUserListView.swift
////  Clique
////
////  Created by Rod Tavangar on 6/27/24.
////
//
//import SwiftUI
//
//struct SearchableUserListView: View {
//    @Environment(\.dismiss) var dismiss
//    @Environment(TabViewCoordinator.self) private var tabCoordinator
//    @StateObject var viewModel = UserListViewModel()
//    
//    @State private var searchText = ""
//    
//    private let config: UserListConfig
//    
//    init(config: UserListConfig) {
//        self.config = config
//    }
//    
//    var body: some View {
//        ScrollView {
//            LazyVStack(spacing: 12) {
//                ForEach(viewModel.users.filter { searchText.isEmpty || (($0.firstname?.localizedCaseInsensitiveContains(searchText)) != nil)}) { user in
//                    HStack {
//                        NavigationLink(value: user) {
//                            UserPfpAsyncView(pfp: user.profilePic, size: 32)
//                            
//                            VStack(alignment: .leading) {
//                                Text(user.username)
//                                    .fontWeight(.semibold)
//                                
//                                Text(user.fullname)
//                            }
//                            .font(.footnote)
//                            
//                            Spacer()
//                        }.buttonStyle(.noHighlight)
//                    }
//                    .foregroundStyle(.primary)
//                    .padding(.horizontal)
//                }
//            }
//            .padding(.top, 8)
//            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search...")
//        }
//        .navigationTitle("Members")
//        .navigationBarTitleDisplayMode(.inline)
//        .toolbar {
//            ToolbarItem(placement: .topBarLeading) {
//                Image(systemName: "chevron.left")
//                    .imageScale(.large)
//                    .onTapGesture {
//                        dismiss()
//                    }
//            }
//        }
//        .task {
//            viewModel.fetchUsers(forConfig: config)
//        }
//    }
//}
//
//#Preview {
//    SearchableUserListView(config: .search)
//        .environment(TabViewCoordinator())
//        .environmentObject(UserListViewModel())
//}
