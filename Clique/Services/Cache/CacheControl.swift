//
//  CacheControl.swift
//  Clique
//
//  Created by Assistant on 2025-08-14.
//

import SwiftUI

@Observable class CacheControl {
    static let shared = CacheControl()
    
    let cacheManager = CacheManager.shared
    
    private init() {}
    
    func setCacheMode(_ mode: CachePolicy.CacheMode) async {
        await cacheManager.setCacheMode(mode)
    }
    
    func getCacheMode() async -> CachePolicy.CacheMode {
        await cacheManager.getCacheMode()
    }
    
    func clearCache() async {
        await cacheManager.invalidateAll()
    }
    
    func getCacheStats() async -> CacheStats {
        await cacheManager.cacheStats()
    }
    
    func enableCache() async {
        await setCacheMode(.normal)
    }
    
    func disableCache() async {
        await setCacheMode(.bypass)
    }
    
    func forceRefresh() async {
        await setCacheMode(.forceRefresh)
    }
}

extension View {
    func cacheMode(_ mode: CachePolicy.CacheMode) -> some View {
        self.task {
            await CacheControl.shared.setCacheMode(mode)
        }
    }
    
    func clearCacheOnAppear() -> some View {
        self.task {
            await CacheControl.shared.clearCache()
        }
    }
}
