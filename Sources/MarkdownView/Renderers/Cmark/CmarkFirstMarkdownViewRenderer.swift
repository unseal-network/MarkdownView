//
//  CmarkFirstMarkdownViewRenderer.swift
//  MarkdownView
//
//  Created by Yanan Li on 2025/4/12.
//

import SwiftUI
import Markdown

struct CmarkFirstMarkdownViewRenderer: MarkdownViewRenderer {    
    func makeBody(
        content: MarkdownContent,
        configuration: MarkdownRendererConfiguration
    ) -> some View {
        _makeAndCacheBody(
            content: content,
            configuration: configuration
        )
    }
    
    private func _makeAndCacheBody(
        content: MarkdownContent,
        configuration: MarkdownRendererConfiguration
    ) -> some View {
        if !configuration.isStreaming,
           let cached = CacheStorage.shared.withCacheIfAvailable(
            content,
            type: Cache.self
        ), cached.configuration == configuration {
            return AnyView(cached.renderedView)
        }
        
        var parseOptions = ParseOptions()
        if !configuration.allowedBlockDirectiveRenderers.isEmpty {
            parseOptions.insert(.parseBlockDirectives)
        }
        
        let renderedView = CmarkNodeVisitor(configuration: configuration)
            .makeBody(for: content.parse(options: parseOptions))
            .erasedToAnyView()
        
        // Streaming prefixes are ephemeral. Caching each prefix retains every
        // previous AST/view tree and grows memory with token count.
        if !configuration.isStreaming {
            CacheStorage.shared.addCache(
                Cache(
                    markdownContent: content,
                    configuration: configuration,
                    renderedView: renderedView
                )
            )
        }
        
        return renderedView
    }
}

extension CmarkFirstMarkdownViewRenderer {
    struct Cache: Cacheable {
        var markdownContent: MarkdownContent
        var configuration: MarkdownRendererConfiguration
        var renderedView: any View
        
        var cacheKey: some Hashable { markdownContent }
    }
}
