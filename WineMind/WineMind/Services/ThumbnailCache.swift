import UIKit
import ImageIO

/// Downsamples wine photos to small thumbnails off the main thread and caches the
/// results. Cellar rows render a 72x96 thumbnail, but the stored photo is a
/// full-resolution camera image — decoding that on the main thread per row per
/// scroll caused jank and high memory. This decodes once, small, in the background.
actor ThumbnailCache {
    static let shared = ThumbnailCache()

    private let cache = NSCache<NSString, UIImage>()

    /// Returns a cached thumbnail for `id`, downsampling from `data` on first use.
    /// `maxPixel` is the longest edge, in pixels, of the produced thumbnail.
    func thumbnail(for id: UUID, data: Data, maxPixel: Int = 240) -> UIImage? {
        let key = id.uuidString as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let image = Self.downsample(data: data, maxPixel: maxPixel) else {
            return nil
        }
        cache.setObject(image, forKey: key)
        return image
    }

    private static func downsample(data: Data, maxPixel: Int) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }
        let thumbOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
