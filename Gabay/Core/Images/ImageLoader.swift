//
//  ImageLoader.swift
//  Gabay
//  Created by John Patrick Echavez on 7/29/26.
//

import ImageIO
import SwiftUI
import UIKit
import os

protocol ImageLoading: Sendable {
    func image(for url: URL) async throws -> UIImage
    func evict(_ url: URL) async
    func clear() async

    func trimMemory() async
}

enum ImageLoaderError: Error, Equatable {
    case invalidImageData
    case httpStatus(Int)
}

// Two layers: decoded images in memory, raw bytes on disk via URLCache.
actor ImageLoader: ImageLoading {

    static let shared = ImageLoader()

    private let memory = NSCache<NSURL, UIImage>()

    private let session: URLSession

    // Longest edge we decode to — past a full-width phone image is wasted memory.
    private let maxPixelSize: CGFloat

    // One download per URL, however many callers ask for it at once.
    private var inFlight: [URL: Task<UIImage, any Error>] = [:]

    private var urlCache: URLCache? { session.configuration.urlCache }

    init(maxPixelSize: CGFloat = 1600, session: URLSession = ImageLoader.makeSession()) {
        self.maxPixelSize = maxPixelSize
        self.session = session

        memory.countLimit = 100
        memory.totalCostLimit = 100 * 1024 * 1024
    }

    // Its own cache, so images don't crowd out API responses.
    static func makeSession(diskCapacity: Int = 256 * 1024 * 1024) -> URLSession {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]

        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(
            memoryCapacity: 16 * 1024 * 1024,
            diskCapacity: diskCapacity,
            directory: caches.appendingPathComponent("ImageCache", isDirectory: true)
        )
        return URLSession(configuration: configuration)
    }

    // Cached bytes are used as-is; callers evict the URL when the image changes.
    private static func request(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        return request
    }

    func image(for url: URL) async throws -> UIImage {
        if let cached = memory.object(forKey: url as NSURL) {
            return cached
        }

        if let existing = inFlight[url] {
            return try await existing.value
        }

        let task = Task<UIImage, any Error> { [session, urlCache, maxPixelSize] in
            let request = Self.request(for: url)
            let (data, response) = try await session.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                throw ImageLoaderError.invalidImageData
            }
            guard (200..<300).contains(http.statusCode) else {
                throw ImageLoaderError.httpStatus(http.statusCode)
            }
            guard let image = Self.decode(data, maxPixelSize: maxPixelSize) else {
                throw ImageLoaderError.invalidImageData
            }

            // CDNs often send `no-store`; save it ourselves and let URLCache cap the size.
            urlCache?.storeCachedResponse(
                CachedURLResponse(response: response, data: data, storagePolicy: .allowed),
                for: request
            )

            return image
        }
        inFlight[url] = task

        do {
            let image = try await task.value
            inFlight[url] = nil
            memory.setObject(image, forKey: url as NSURL, cost: image.estimatedBytes)
            return image
        } catch {
            inFlight[url] = nil
            throw error
        }
    }

    // For when the URL stays the same but the picture behind it changed.
    func evict(_ url: URL) {
        memory.removeObject(forKey: url as NSURL)
        urlCache?.removeCachedResponse(for: Self.request(for: url))
    }

    func clear() {
        memory.removeAllObjects()
        urlCache?.removeAllCachedResponses()
    }

    // On a memory warning. The disk copy survives.
    func trimMemory() {
        memory.removeAllObjects()
    }

    // Decodes to the size we draw at; `.frame` alone would keep the full bitmap.
    private static func decode(_ data: Data, maxPixelSize: CGFloat) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,   // honours EXIF rotation
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]

        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

private extension UIImage {

    var estimatedBytes: Int {
        guard let cgImage else { return 1 }
        return cgImage.bytesPerRow * cgImage.height
    }
}

private struct ImageLoaderKey: EnvironmentKey {
    static let defaultValue: any ImageLoading = ImageLoader.shared
}

extension EnvironmentValues {
    var imageLoader: any ImageLoading {
        get { self[ImageLoaderKey.self] }
        set { self[ImageLoaderKey.self] = newValue }
    }
}
