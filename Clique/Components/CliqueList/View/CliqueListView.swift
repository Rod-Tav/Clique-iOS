////
////  CliqueListView.swift
////  Clique
////
////  Created by Rod Tavangar on 7/21/24.
////
//
//import SwiftUI
//
//struct CliqueListView: View {
//    @StateObject var viewModel: CliqueListViewModel
//    
//    @State private var searchText: String = ""
//    
//    var type: CliqueListType = .standard
//    
//    init(type: CliqueListType, config: CliqueListConfig) {
//        self._viewModel = StateObject(wrappedValue: CliqueListViewModel(config: config))
//        self.type = type
//    }
//    
//    var body: some View {
//        VStack {
//            if viewModel.cliques.count == 0 {
//                Text("No cliques to show.")
//            } else {
//                LazyVStack(spacing: 16) {
//                    ForEach(viewModel.cliques.filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText)}) { clique in
//                        NavigationLink(value: clique) {
//                            CliqueListCellView(clique: clique, type: type)
//                        }.buttonStyle(.noHighlight)
//                    }
//                }
//            }
//        }
//    }
//}
//
//#Preview {
//    CliqueListView(type: .standard, config: .cliques(uid: User.MOCK_USERS[0].id))
//}
