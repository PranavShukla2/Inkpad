//
//  PageDrawings.swift
//  Inkpad
//

import Foundation

/// Encodes per-page PencilKit drawing data for storage in a single blob.
nonisolated enum PageDrawings {
    static func decode(_ data: Data?) -> [Int: Data] {
        guard let data, let pages = try? PropertyListDecoder().decode([Int: Data].self, from: data) else {
            return [:]
        }
        return pages
    }

    static func encode(_ pages: [Int: Data]) -> Data? {
        try? PropertyListEncoder().encode(pages)
    }
}
