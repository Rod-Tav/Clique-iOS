////
////  UserImagePrefetcher.swift
////  Clique
////
////  Created by Rod Tavangar on 3/5/25.
////
//
//import Foundation
//import Kingfisher
//
//final class UserImagePrefetcher {
//    static let instance = UserImagePrefetcher()
//    
//    private var prefetchers: [String: Kingfisher.ImagePrefetcher] = [:]
//
//    private init() {}
//
//    func startPrefetching(userIds: [String], userStore: UserStore) {
//        Task { @MainActor in
//            let urls = userIds.compactMap { userStore.users[$0]?.profilePic }
//                .compactMap { URL(string: $0) }
//            let urlsToFetch = urls.filter { !ImageCache.default.isCached(forKey: $0.absoluteString) }
//            
//            guard !urlsToFetch.isEmpty else { return }
//            
//            let prefetcher = Kingfisher.ImagePrefetcher(urls: urlsToFetch)
//            prefetchers["users"] = prefetcher
//            prefetcher.start()
//        }
//    }
//
//    func stopPrefetching() {
//        prefetchers["users"]?.stop()
//        prefetchers.removeValue(forKey: "users")
//    }
//}
