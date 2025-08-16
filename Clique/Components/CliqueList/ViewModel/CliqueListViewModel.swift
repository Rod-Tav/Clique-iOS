////
////  CliqueListViewModel.swift
////  Clique
////
////  Created by Rod Tavangar on 6/16/24.
////
//
//import Foundation
//
///// The view model for fetching a list of cliques.
///// - Parameters:
/////     - config: the type of clique list request as a ``CliqueListConfig``
//@MainActor
//final class CliqueListViewModel: ObservableObject {
//    @Published private(set) var cliques = [Clique]()
//    
//    init(config: CliqueListConfig) {
//        fetchCliques(forConfig: config)
//    }
//    
//    func fetchCliques(forConfig config: CliqueListConfig) {
//        self.cliques = CliqueService.fetchCliques(forConfig: config)
//    }
//}
