package com.hyperplusq.studyflow.ui

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.LruCache
import androidx.compose.runtime.Composable
import androidx.compose.runtime.State
import androidx.compose.runtime.produceState
import com.hyperplusq.studyflow.data.db.AttachmentEntity
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** 缩略图解码的最长边（px），覆盖列表 44dp、详情 76dp、编辑器 84dp 的缩略图尺寸。 */
private const val ThumbnailMaxDimensionPx = 320

/** 全屏预览解码的最长边（px）：尽量保留清晰度，同时给超大图设一道内存上限。 */
private const val PreviewMaxDimensionPx = 4096

/** 缩略图缓存上限（KB）。320×320 的图约 400KB，可缓存约 40 张。 */
private const val ThumbnailCacheMaxSizeKb = 16 * 1024

/**
 * 进程内缩略图缓存：列表滚动、重复出现的同一批附件不再反复解码原图。
 * 键包含图片字节数，导入/编辑替换图片后会自然命中新的条目。
 */
private object ThumbnailCache {
    private val cache = object : LruCache<String, Bitmap>(ThumbnailCacheMaxSizeKb) {
        override fun sizeOf(key: String, value: Bitmap): Int = (value.byteCount / 1024).coerceAtLeast(1)
    }

    fun get(key: String): Bitmap? = cache.get(key)

    fun put(key: String, bitmap: Bitmap) {
        cache.put(key, bitmap)
    }
}

/** 附件缩略图/预览的缓存键：只用标识与体积，避免每次重组都遍历整个字节数组。 */
internal fun attachmentCacheKey(attachment: AttachmentEntity): String =
    "${attachment.id}:${attachment.imageData.size}"

/** 在不超过最长边的前提下，计算 BitmapFactory 需要的 2 的幂采样率。 */
internal fun sampleSizeFor(width: Int, height: Int, maxDimension: Int): Int {
    if (width <= 0 || height <= 0 || maxDimension <= 0) return 1
    val longest = maxOf(width, height)
    var sample = 1
    while (longest / sample > maxDimension) {
        sample *= 2
    }
    return sample
}

/** 先只读图片头拿到尺寸，再按采样率解码，避免把原图整张解进内存。 */
internal fun decodeSampledBitmap(data: ByteArray, maxDimension: Int): Bitmap? {
    if (data.isEmpty()) return null
    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    BitmapFactory.decodeByteArray(data, 0, data.size, bounds)
    if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null

    val options = BitmapFactory.Options().apply {
        inSampleSize = sampleSizeFor(bounds.outWidth, bounds.outHeight, maxDimension)
    }
    return BitmapFactory.decodeByteArray(data, 0, data.size, options)
}

/** 图片解码结果：加载中 / 解码失败 / 已就绪。 */
internal sealed interface DecodedImage {
    data object Loading : DecodedImage
    data object Failed : DecodedImage
    data class Ready(val bitmap: Bitmap) : DecodedImage
}

/**
 * 异步获取缩略图：命中缓存立即显示；未命中在 IO 线程按采样率解码，
 * 完成后写入缓存。解码不占主线程，滚动时不会卡顿。
 */
@Composable
internal fun rememberAttachmentThumbnail(attachment: AttachmentEntity): State<DecodedImage> {
    val key = attachmentCacheKey(attachment)
    return produceState<DecodedImage>(initialValue = DecodedImage.Loading, key1 = key) {
        ThumbnailCache.get(key)?.let {
            value = DecodedImage.Ready(it)
            return@produceState
        }
        val decoded = withContext(Dispatchers.IO) {
            decodeSampledBitmap(attachment.imageData, ThumbnailMaxDimensionPx)
        }
        if (decoded == null) {
            value = DecodedImage.Failed
        } else {
            ThumbnailCache.put(key, decoded)
            value = DecodedImage.Ready(decoded)
        }
    }
}

/** 全屏预览用的图片：同样在 IO 线程解码，但保留更高分辨率且不进缩略图缓存。 */
@Composable
internal fun rememberAttachmentPreviewImage(attachment: AttachmentEntity): State<DecodedImage> {
    val key = attachmentCacheKey(attachment)
    return produceState<DecodedImage>(initialValue = DecodedImage.Loading, key1 = key) {
        val decoded = withContext(Dispatchers.IO) {
            decodeSampledBitmap(attachment.imageData, PreviewMaxDimensionPx)
        }
        value = if (decoded == null) DecodedImage.Failed else DecodedImage.Ready(decoded)
    }
}
