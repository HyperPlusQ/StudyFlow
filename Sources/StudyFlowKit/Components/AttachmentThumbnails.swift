import ImageIO
import SwiftUI
import UIKit

/// 图片附件的异步缩略图加载：ImageIO 采样解码 + 进程内缓存。
///
/// 直接 `UIImage(data:)` 会把千万像素级原图解成约 48MB 的位图，
/// 列表/详情里同时出现几张就会明显卡顿，甚至触发内存崩溃。
@MainActor
enum AttachmentImageLoader {
    /// 缩略图最长边（像素），覆盖详情画廊 180pt@3x 的显示需要。
    static let thumbnailMaxPixelSize = 512

    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 24 * 1024 * 1024
        cache.countLimit = 64
        return cache
    }()

    /// 后台按最长边生成缩略图；命中缓存时直接返回。
    static func thumbnail(
        id: UUID,
        data: Data,
        maxPixelSize: Int = thumbnailMaxPixelSize
    ) async -> UIImage? {
        let key = "\(id.uuidString)-\(maxPixelSize)" as NSString
        if let cached = cache.object(forKey: key) { return cached }

        let image = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: makeThumbnail(from: data, maxPixelSize: maxPixelSize))
            }
        }
        if let image {
            let cost = image.cgImage.map { $0.width * $0.height * 4 } ?? 0
            cache.setObject(image, forKey: key, cost: cost)
        }
        return image
    }

    /// 用 ImageIO 直接产出缩略图，避免先解码整张原图再缩放。
    nonisolated private static func makeThumbnail(from data: Data, maxPixelSize: Int) -> UIImage? {
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
        return UIImage(cgImage: cgImage)
    }
}

/// 异步显示附件缩略图：加载中/解码失败显示占位，不在主线程同步解码原图。
struct AttachmentThumbnailImage: View {
    private let id: UUID
    private let data: Data
    private let maxPixelSize: Int
    private let contentMode: ContentMode

    @State private var image: UIImage?

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
                Image(uiImage: image)
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
