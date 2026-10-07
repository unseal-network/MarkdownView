//
//  MarkdownContent.swift
//  MarkdownView
//
//  Created by Yanan Li on 2025/2/9.
//

import Foundation
@preconcurrency import Markdown

// MARK: - Raw

enum RawMarkdownContent: Sendable, Hashable {
    case plainText(String)
    case url(URL)
    
    public var text: String {
        switch self {
        case .plainText(let text):
            return text
        case .url(let url):
            return (try? String(contentsOf: url)) ?? ""
        }
    }
    
    public var source: URL? {
        if case .url(let url) = self {
            return url
        }
        return nil
    }
}

// MARK: - Parsed Content

/// A Sendable markdown content that can be used to render content and supports on-demand parsing.
public struct MarkdownContent: Sendable {
    var raw: RawMarkdownContent
    
    class ParsedDocumentStore: /* NSLock */ @unchecked Sendable {
        private var lock = NSLock()
        private var caches: [ParseOptions.RawValue : Document] = [:]
        private var textMaps: [ParseOptions.RawValue : TextNodeMap] = [:]
        
        fileprivate func parse(_ rawContent: RawMarkdownContent, options: ParseOptions = ParseOptions()) -> Document {
            lock.lock()
            defer { lock.unlock() }
            
            if let cached = caches[options.rawValue] {
                return cached
            }
            
            let document = Document(
                parsing: rawContent.text,
                source: rawContent.source,
                options: options
            )
            caches[options.rawValue] = document
            return document
        }
        
        fileprivate func textMap(_ rawContent: RawMarkdownContent, options: ParseOptions) -> TextNodeMap {
            let document = parse(rawContent, options: options)
            return lock.withLock {
                if let cached = textMaps[options.rawValue] { return cached }
                let map = TextNodeMap.build(from: document)
                textMaps[options.rawValue] = map
                return map
            }
        }

        var documents: LazySequence<Dictionary<ParseOptions.RawValue, Document>.Values> {
            lock.withLock {
                caches.values.lazy
            }
        }
        
        var hasParsedDocument: Bool {
            !documents.isEmpty
        }
    }
    var store: ParsedDocumentStore
    
    /// Create immutable text content that can be prepared off the main actor.
    public init(_ text: String) {
        self.init(raw: .plainText(text))
    }

    /// Warm the default CommonMark AST and streaming offsets. Synchronous by design:
    /// call from a background task, then pass the returned content to MarkdownView.
    /// Custom block-directive parse options are still prepared on demand.
    public func preparingForRendering() -> MarkdownContent {
        _ = store.textMap(raw, options: ParseOptions())
        return self
    }

    func textNodeMap(options: ParseOptions) -> TextNodeMap {
        store.textMap(raw, options: options)
    }

    internal init(raw: RawMarkdownContent) {
        self.raw = raw
        self.store = ParsedDocumentStore()
    }
    
    func parse(options: ParseOptions = ParseOptions()) -> Document {
        store.parse(raw, options: options)
    }
}

extension MarkdownContent: Hashable {
    public static func == (lhs: MarkdownContent, rhs: MarkdownContent) -> Bool {
        lhs.raw == rhs.raw
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(raw)
    }
}
