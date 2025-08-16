//
//  DiskCacheStorage.swift
//  Clique
//
//  Created by Assistant on 2025-01-15.
//

import Foundation

actor DiskCacheStorage: CacheStorage {
    typealias Value = Data
    
    private let cacheDirectory: URL
    private let maxSize: Int
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    init(maxSize: Int = 100 * 1024 * 1024) {
        self.maxSize = maxSize
        
        let documentsPath = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDirectory = documentsPath.appendingPathComponent("CliqueAPICache")
        
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func get(key: String) async -> CacheEntry<Data>? {
        let fileURL = cacheURL(for: key)
        
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let entry = try decoder.decode(CacheEntry<Data>.self, from: data)
            
            if entry.isExpired {
                await remove(key: key)
                return nil
            }
            
            return entry
        } catch {
            print("Cache read error for key \(key): \(error)")
            await remove(key: key)
            return nil
        }
    }
    
    func set(key: String, value: CacheEntry<Data>) async {
        await ensureCacheSize()
        
        let fileURL = cacheURL(for: key)
        
        do {
            let data = try encoder.encode(value)
            try data.write(to: fileURL)
        } catch {
            print("Cache write error for key \(key): \(error)")
        }
    }
    
    func remove(key: String) async {
        let fileURL = cacheURL(for: key)
        try? fileManager.removeItem(at: fileURL)
    }
    
    func removeAll() async {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func removeExpired() async {
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else { return }
        
        for fileURL in files {
            let key = fileURL.deletingPathExtension().lastPathComponent
            _ = await get(key: key)
        }
    }
    
    func keys() async -> Set<String> {
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else {
            return []
        }
        
        return Set(files.map { $0.deletingPathExtension().lastPathComponent })
    }
    
    private func cacheURL(for key: String) -> URL {
        let safeKey = key.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return cacheDirectory.appendingPathComponent("\(safeKey).cache")
    }
    
    private func ensureCacheSize() async {
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]) else { return }
        
        var fileInfos: [(url: URL, size: Int, date: Date)] = []
        var totalSize = 0
        
        for fileURL in files {
            guard let attributes = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
                  let size = attributes.fileSize,
                  let date = attributes.contentModificationDate else { continue }
            
            fileInfos.append((fileURL, size, date))
            totalSize += size
        }
        
        if totalSize > maxSize {
            fileInfos.sort { $0.date < $1.date }
            
            var sizeToRemove = totalSize - (maxSize * 3 / 4)
            
            for fileInfo in fileInfos {
                guard sizeToRemove > 0 else { break }
                
                try? fileManager.removeItem(at: fileInfo.url)
                sizeToRemove -= fileInfo.size
            }
        }
    }
    
    func cacheInfo() async -> (entries: Int, size: Int) {
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return (0, 0)
        }
        
        var totalSize = 0
        for fileURL in files {
            if let attributes = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let size = attributes.fileSize {
                totalSize += size
            }
        }
        
        return (files.count, totalSize)
    }
}