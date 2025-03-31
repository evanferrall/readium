//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
#if os(iOS) || os(tvOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

#if os(iOS) || os(tvOS)
public typealias PlatformImage = UIImage
#elseif os(macOS)
public typealias PlatformImage = NSImage
#else
#warning("PlatformImage not defined for this platform")
public typealias PlatformImage = NSObject
#endif

/// A `CoverService` which holds a lazily generated cover bitmap in memory.
public final class GeneratedCoverService: CoverService {
    enum Error: Swift.Error {
        case generationFailed
    }

    private var _cover: ReadResult<PlatformImage>?
    private let makeCover: () async -> ReadResult<PlatformImage>

    public init(makeCover: @escaping () async -> ReadResult<PlatformImage>) {
        self.makeCover = makeCover
    }

    public convenience init(cover: PlatformImage) {
        self.init(makeCover: { .success(cover) })
    }

    private let coverLink = Link(
        href: "~readium/cover",
        mediaType: .png,
        rel: .cover
    )

    private func cachedCover() async -> ReadResult<PlatformImage> {
        if _cover == nil {
            _cover = await makeCover()
        }
        return _cover!
    }

    public func cover() async -> ReadResult<PlatformImage?> {
        await cachedCover().map { $0 as PlatformImage? }
    }

    public var links: [Link] { [coverLink] }

    public func get<T>(_ href: T) -> (any Resource)? where T: URLConvertible {
        guard href.anyURL.isEquivalentTo(coverLink.url()) else {
            return nil
        }

        return CoverResource(cover: cachedCover)
    }

    public static func makeFactory(makeCover: @escaping () async -> ReadResult<PlatformImage>) -> (PublicationServiceContext) -> GeneratedCoverService? {
        { _ in GeneratedCoverService(makeCover: makeCover) }
    }

    public static func makeFactory(cover: PlatformImage) -> (PublicationServiceContext) -> GeneratedCoverService? {
        { _ in GeneratedCoverService(cover: cover) }
    }

    private class CoverResource: Resource {
        private let cover: () async -> ReadResult<PlatformImage>

        public init(cover: @escaping () async -> ReadResult<PlatformImage>) {
            self.cover = cover
        }

        let sourceURL: AbsoluteURL? = nil

        func estimatedLength() async -> ReadResult<UInt64?> {
            .success(nil)
        }

        func properties() async -> ReadResult<ResourceProperties> {
            #if os(iOS) || os(tvOS)
            guard let data = cover().flatMap({ $0.pngData() }) else {
                return .failure(.decoding("Failed to convert the cover bitmap to PNG data"))
            }
            #elseif os(macOS)
            guard let tiffData = cover().flatMap({ $0.tiffRepresentation }), let bitmap = NSBitmapImageRep(data: tiffData), let data = bitmap.representation(using: .png, properties: [:]) else {
                return .failure(.decoding("Failed to convert the cover bitmap to PNG data"))
            }
            #else
            return .failure(.decoding("Cannot get PNG data for cover on this platform"))
            #endif

            return .success(ResourceProperties())
        }

        func stream(range: Range<UInt64>?, consume: @escaping (Data) -> Void) async -> ReadResult<Void> {
            await cover().flatMap {
                #if os(iOS) || os(tvOS)
                guard let data = $0.pngData() else {
                    return .failure(.decoding("Failed to convert the cover bitmap to PNG data"))
                }
                #elseif os(macOS)
                guard let tiffData = $0.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiffData), let data = bitmap.representation(using: .png, properties: [:]) else {
                    return .failure(.decoding("Failed to convert the cover bitmap to PNG data"))
                }
                #else
                return .failure(.decoding("Cannot get PNG data for cover on this platform"))
                #endif

                consume(data)
                return .success(())
            }
        }
    }
}
