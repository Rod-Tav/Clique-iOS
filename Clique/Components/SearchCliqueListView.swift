////
////  SearchCliqueListView.swift
////  Clique
////
////  Created by Rod Tavangar on 6/16/24.
////
//
//import SwiftUI
//
//struct SearchCliqueListView: View {
//    @StateObject var viewModel: CliqueListViewModel
//    
//    let searchText: String
//    
//    private let config: CliqueListConfig
//    
//    init(config: CliqueListConfig, searchText: String) {
//        self.config = config
//        self.searchText = searchText
//        self._viewModel = StateObject(wrappedValue: CliqueListViewModel(config: config))
//    }
//    
//    init(config: CliqueListConfig) {
//        self.config = config
//        self.searchText = ""
//        self._viewModel = StateObject(wrappedValue: CliqueListViewModel(config: config))
//    }
//    
//    var body: some View {
//        ScrollView {
//            LazyVStack(spacing: 12) {
//                ForEach(viewModel.cliques.filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText)}) { clique in
//                    NavigationLink(value: clique) {
//                        CliqueListCellView(clique: clique, type: .standard)
//                    }.buttonStyle(.noHighlight)
//                }
//            }
//        }
//    }
//}
//
//#Preview {
//    SearchCliqueListView(config: .search, searchText: "")
//}
