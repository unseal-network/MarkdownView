//
//  CacheStorage.swift
//  MarkdownView
//
//  Created by Yanan Li on 2025/3/29.
//

import Foundation

class CacheStorage: @unchecked Sendable {
    static let shared = CacheStorage()
    
    private var caches: [AnyHashable : any Cacheable] = [:]
    private var recency: [AnyHashable: UInt64] = [:]
    private var accessCounter: UInt64 = 0
    // A virtualized history must not retain every view tree ever scrolled through.
    private let maximumEntries = 128
    private var lock: NSLock
    
    private init() {
        lock = NSLock()
        self.caches = [:]
    }
    
    func addCache(_ cache: some Cacheable) {
        lock.withLock {
            let key = AnyHashable(cache.cacheKey)
            caches[key] = cache
            touch(key)
            if caches.count > maximumEntries,
               let oldest = recency.min(by: { $0.value < $1.value })?.key {
                caches[oldest] = nil
                recency[oldest] = nil
            }
        }
    }
    
    // Call only while holding lock.
    private func touch(_ key: AnyHashable) {
        accessCounter &+= 1
        recency[key] = accessCounter
    }

    func removeCache(_ key: AnyHashable) {
        lock.withLock {
            caches[key] = nil
            recency[key] = nil
        }
    }
    
    func withCacheIfAvailable<T: Sendable>(
        _ key: AnyHashable,
        action: @Sendable @escaping (any Cacheable) throws -> T
    ) rethrows -> T? {
        lock.lock()
        defer { lock.unlock() }
        
        if let cache = caches[key] {
            touch(key)
            return try action(cache)
        }
        return nil
    }
    
    func withCacheIfAvailable<T: Cacheable & Sendable>(
        _ key: AnyHashable,
        type: T.Type
    ) -> T? {
        lock.lock()
        defer { lock.unlock() }
        
        if let cache = caches[key] {
            touch(key)
            return T(fromCache: cache)
        }
        return nil
    }
}
