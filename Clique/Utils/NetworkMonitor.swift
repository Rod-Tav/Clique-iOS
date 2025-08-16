////
////  NetworkMonitor.swift
////  Clique
////
////  Created by Rod Tavangar on 12/10/24.
////
//
//import Foundation
//import Network
//
//@Observable
//final class NetworkMonitor {
//    private let networkMonitor = NWPathMonitor()
//    private let workerQueue = DispatchQueue(label: "Monitor")
//    var isConnected = false
//    
//    init() {
//        networkMonitor.pathUpdateHandler = { path in
//            self.isConnected = path.status == .satisfied
//        }
//        networkMonitor.start(queue: workerQueue)
//    }
//}
