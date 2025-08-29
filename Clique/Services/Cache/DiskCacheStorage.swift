//
//  DiskCacheStorage.swift
//  Clique
//
//  Created by Assistant on 2025-01-15.
//

import Foundation
import CryptoKit

extension Character {
    var isHexDigit: Bool {
        return isNumber || ("a"..."f").contains(lowercased().first!) || ("A"..."F").contains(self)
    }
}

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
        
        // Clean up legacy cache files with problematic naming on startup
        Task {
            await cleanupLegacyCacheFiles()
        }
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
        
        // Note: With hash-based filenames, we can't reverse-engineer the original keys
        // This method now returns the hash values as keys for cache management purposes
        return Set(files.map { $0.deletingPathExtension().lastPathComponent })
    }
    
    private func cacheURL(for key: String) -> URL {
        // Use SHA256 hash to create safe, collision-resistant filenames
        // This prevents filesystem "filename too long" errors (Code=63)
        let keyData = Data(key.utf8)
        let hash = SHA256.hash(data: keyData)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        return cacheDirectory.appendingPathComponent("\(hashString).cache")
    }
    
    private func cleanupLegacyCacheFiles() async {
        // Clean up cache files created with the old naming scheme that may have
        // problematic characters or excessive length
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else { return }
        
        for fileURL in files {
            let filename = fileURL.deletingPathExtension().lastPathComponent
            
            // If filename contains underscores (old naming scheme) or is too long, remove it
            // The new hash-based filenames are exactly 64 hex characters
            if filename.contains("_") || filename.count != 64 || !filename.allSatisfy(\.isHexDigit) {
                try? fileManager.removeItem(at: fileURL)
            }
        }
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