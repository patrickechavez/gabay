//
//  Mocks.swift
//  Gabay
//  Created by John Patrick Echavez on 7/29/26.
//

#if DEVELOPMENT

import Foundation
import UIKit

actor MockImageLoader: ImageLoading {

    private(set) var evictedURLs: [URL] = []

    init() {}

    func image(for url: URL) async throws -> UIImage {
        throw ImageLoaderError.invalidImageData
    }

    func evict(_ url: URL) async {
        evictedURLs.append(url)
    }

    func clear() async {
        evictedURLs.removeAll()
    }

    func trimMemory() async {}
}

#endif
