////
////  CliqueImagePrefetcher.swift
////  Clique
////
////  Created by Rod Tavangar on 3/5/25.
////
//
//import Foundation
//import Kingfisher
//
//final class CliqueImagePrefetcher {
//    static let instance = CliqueImagePrefetcher()
//    
//    private var prefetchers: [String: Kingfisher.ImagePrefetcher] = [:]
//
//    private init() {}
//
//    func startPrefetching(clique: Clique) {
//        let urls = [clique.cliquePic, clique.cliqueBanner].compactMap { URL(string: $0) }
//        let urlsToFetch = urls.filter { !ImageCache.default.isCached(forKey: $0.absoluteString) }
//
//        guard !urlsToFetch.isEmpty else { return }
//        
//        let prefetcher = Kingfisher.ImagePrefetcher(urls: urlsToFetch)
//        prefetchers[clique.id] = prefetcher
//        prefetcher.start()
//    }
//
//    func stopPrefetching(cliqueId: String) {
//        prefetchers[cliqueId]?.stop()
//        prefetchers.removeValue(forKey: cliqueId)
//    }
//}
