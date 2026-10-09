import AppKit
import ImageIO
import SwiftUI

/// 图片附件的异步缩略图加载：ImageIO 采样解码 + 进程内缓存。
///
/// `NSImage(data:)` 会把整张原图交给渲染线程解码，列表/详情里同时出现几张
/// 就会明显掉帧；这里改成后台按最长边生成缩略图并缓存。
@MainActor
enum AttachmentImageLoader {
    /// 缩略图最长边（像素），覆盖详情画廊 180pt 的显示需要。
    static let thumbnailMaxPixelSize = 512

    private static let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.totalCostLimit = 24 * 1024 * 1024
        cache.countLimit = 64
        return cache
    }()

    /// 后台按最长边生成缩略图；命中缓存时直接返回。
    static func thumbnail(
        id: UUID,
        data: Data,
        maxPixelSize: Int = thumbnailMaxPixelSize
    ) async -> NSImage? {
        let key = "\(id.uuidString)-\(maxPixelSize)" as NSString
        if let cached = cache.object(forKey: key) { return cached }

        let image = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: makeThumbnail(from: data, maxPixelSize: maxPixelSize))
            }
        }
        if let image {
            // 缩略图尺寸有上界，用最大可能像素数作为缓存权重即可。
            cache.setObject(image, forKey: key, cost: maxPixelSize * maxPixelSize * 4)
        }
        return image
    }

    /// 用 ImageIO 直接产出缩略图，避免先解码整张原图再缩放。
    nonisolated private static func makeThumbnail(from data: Data, maxPixelSize: Int) -> NSImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            // 按 EXIF 方向摆正，避免横竖颠倒。
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: .zero)
    }
}

/// 异步显示附件缩略图：加载中/解码失败显示占位，不在主线程解码原图。
struct AttachmentThumbnailImage: View {
    private let id: UUID
    private let data: Data
    private let maxPixelSize: Int
    private let contentMode: ContentMode

    @State private var image: NSImage?

    init(
        attachment: ImageAttachment,
        maxPixelSize: Int = AttachmentImageLoader.thumbnailMaxPixelSize,
        contentMode: ContentMode = .fill
    ) {
        self.init(
            id: attachment.id,
            data: attachment.imageData,
            maxPixelSize: maxPixelSize,
            contentMode: contentMode
        )
    }

    init(
        id: UUID,
        data: Data,
        maxPixelSize: Int = AttachmentImageLoader.thumbnailMaxPixelSize,
        contentMode: ContentMode = .fill
    ) {
        self.id = id
        self.data = data
        self.maxPixelSize = maxPixelSize
        self.contentMode = contentMode
    }

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Color.secondary.opacity(0.12)
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: "\(id.uuidString)-\(data.count)") {
            image = await AttachmentImageLoader.thumbnail(
                id: id,
                data: data,
                maxPixelSize: maxPixelSize
            )
        }
    }
}
