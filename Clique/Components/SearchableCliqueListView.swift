////
////  SearchableCliqueListView.swift
////  Clique
////
////  Created by Rod Tavangar on 6/27/24.
////
//
//import SwiftUI
//
//struct SearchableCliqueListView: View {
//    @Environment(\.dismiss) var dismiss
//    @Environment(TabViewCoordinator.self) private var tabCoordinator
//    @StateObject var viewModel: CliqueListViewModel
//    @State private var searchText: String
//    
//    private let config: CliqueListConfig
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
//                    HStack {
//                        NavigationLink(value: clique) {
//                            CliqueListCellView(clique: clique, type: .standard) // TODO: change type
//                        }.buttonStyle(.noHighlight)
//                    }
//                    .foregroundStyle(.primary)
//                }
//            }
//            .padding(.top, 8)
//            .padding(.horizontal, 16)
//            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search...")
//        }
//        .navigationTitle("Cliques")
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
//    }
//}
//
//#Preview {
//    SearchableCliqueListView(config: .search)
//        .environment(TabViewCoordinator())
//}
